import ActivityKit
import Foundation
import Observation
import OSLog
import UIKit

/// Owns the timer and the single Live Activity that mirrors it.
/// `Activity<EyesAttributes>.activities` is the source of truth; never more than one runs.
///
/// Live Activities are snapshots: the island only changes when this process pushes an update.
/// The animation loops below therefore run only while the app is alive (foreground, plus a short
/// grace period after it goes to the background).
@MainActor
@Observable
final class EyesActivityController {
    /// When the running timer started; nil when no timer is running.
    private(set) var startDate: Date?
    /// Timer length in seconds.
    private(set) var totalSeconds: Int
    private(set) var islandEnabled: Bool
    private(set) var activitiesEnabled: Bool
    /// Why the island eyes couldn't start, if the system refused (shown on the main page).
    private(set) var activityError: String?

    private let authorization = ActivityAuthorizationInfo()
    @ObservationIgnored private var enablementTask: Task<Void, Never>?
    @ObservationIgnored private var endTask: Task<Void, Never>?
    /// True while the slow tired close runs, so the normal blink doesn't fight over the lid.
    @ObservationIgnored private var tiredActive = false
    /// The end time the pending "time's up" activity was scheduled for.
    @ObservationIgnored private var timesUpScheduledFor: Date?
    /// Handle to the scheduled "time's up" activity. A pending activity may not show up in
    /// `Activity.activities`, and leaked ones count toward the per-app limit, so it is ended through this.
    @ObservationIgnored private var timesUpHandle: Activity<EyesAttributes>?
    /// Retries starting the activity when the system refused (e.g. the app isn't visible on the phone).
    @ObservationIgnored private var activityRetryTask: Task<Void, Never>?
    @ObservationIgnored private var isSyncing = false
    @ObservationIgnored private var syncAgain = false
    @ObservationIgnored private var wakeTasks: [Task<Void, Never>] = []
    private static let log = Logger(subsystem: "com.guangyang.eyesbuddy", category: "activity")

    // Animation
    @ObservationIgnored private var live: EyesAttributes.ContentState
    @ObservationIgnored private var animationTasks: [Task<Void, Never>] = []
    @ObservationIgnored private var updateSignal: AsyncStream<Void>.Continuation?
    @ObservationIgnored private var graceTask: Task<Void, Never>?
    @ObservationIgnored private var backgroundTaskID = UIBackgroundTaskIdentifier.invalid

    var isRunning: Bool { startDate != nil }
    var endDate: Date? { startDate?.addingTimeInterval(TimeInterval(totalSeconds)) }

    init() {
        TimerNotifications.install()
        totalSeconds = SharedSettings.totalSeconds
        islandEnabled = SharedSettings.islandEnabled
        activitiesEnabled = authorization.areActivitiesEnabled
        live = .make(redLimitSeconds: SharedSettings.totalSeconds)

        if let stored = SharedSettings.timerStart,
           Date.now.timeIntervalSince(stored) < TimeInterval(EyeStyle.maxSessionSeconds) {
            startDate = stored
            scheduleEnd()
        } else {
            SharedSettings.timerStart = nil
        }

        // The phone becoming usable again (unlock, or leaving iPhone Mirroring) is a chance to start
        // an activity that was refused while the app wasn't visible.
        for name in [UIApplication.didBecomeActiveNotification, UIApplication.protectedDataDidBecomeAvailableNotification] {
            wakeTasks.append(Task { [weak self] in
                for await _ in NotificationCenter.default.notifications(named: name) {
                    await self?.startIfNeeded()
                }
            })
        }

        enablementTask = Task { [weak self] in
            guard let updates = self?.authorization.activityEnablementUpdates else { return }
            for await enabled in updates {
                self?.activitiesEnabled = enabled
                if enabled { await self?.startIfNeeded() }
            }
        }
    }

    // MARK: Timer

    /// Start (or restart) the timer from zero.
    func startTimer() async {
        AlarmPlayer.shared.stop()
        await endAll()
        live = .make(redLimitSeconds: totalSeconds)
        startDate = .now
        SharedSettings.timerStart = startDate
        SharedSettings.lastTimerSeconds = totalSeconds
        QuickActions.shared.refresh()
        scheduleEnd()
        await startIfNeeded()
    }

    /// Start a timer of a specific length (used by the home-screen quick actions).
    func startTimer(seconds: Int) async {
        SharedSettings.totalSeconds = seconds
        totalSeconds = SharedSettings.totalSeconds
        await startTimer()
    }

    /// The app language changed: refresh everything that was built with the old language.
    func languageChanged() {
        QuickActions.shared.refresh()
        alarmSettingsChanged()
        Task { await startIfNeeded() }
    }

    /// Stop the timer and the alarm, and take the eyes out of the island.
    func stopTimer() async {
        AlarmPlayer.shared.stop()
        endTask?.cancel()
        TimerNotifications.cancel()
        startDate = nil
        SharedSettings.timerStart = nil
        await endAll()
    }

    func setTotal(_ seconds: Int) async {
        SharedSettings.totalSeconds = seconds
        totalSeconds = SharedSettings.totalSeconds
        guard isRunning else { return }
        scheduleEnd()
        // Re-syncs the running activity and re-schedules the "time's up" one for the new end.
        await startIfNeeded()
    }

    func setIslandEnabled(_ enabled: Bool) async {
        islandEnabled = enabled
        SharedSettings.islandEnabled = enabled
        await startIfNeeded()
    }

    // MARK: Lifecycle

    /// Run on launch and whenever the scene becomes active: makes the activity match the timer.
    /// Overlapping calls (scene change, unlock, timer end, ...) are merged so two runs can never
    /// both create an activity.
    func startIfNeeded() async {
        if isSyncing {
            syncAgain = true
            return
        }
        isSyncing = true
        repeat {
            syncAgain = false
            await syncActivities()
        } while syncAgain
        isSyncing = false
    }

    private func syncActivities() async {
        cancelBackgroundGrace()
        activitiesEnabled = authorization.areActivitiesEnabled
        resumeAlarmIfNeeded()

        // The 8 h system limit ends the activity, so a timer can't outlive it.
        if let start = startDate, Date.now.timeIntervalSince(start) >= TimeInterval(EyeStyle.maxSessionSeconds) {
            startDate = nil
            SharedSettings.timerStart = nil
        }

        guard let start = startDate, islandEnabled else {
            await endAll()
            return
        }
        guard activitiesEnabled else { return }

        // Time is up and this process is running, so turn the running activity red itself: no gap,
        // and the standby "time's up" activity (meant for a suspended app) isn't needed.
        if let end = endDate, Date.now >= end {
            stopAnimating()
            live.isClosed = false
            live.lid = 0
            live.sweep = -1
            live.finished = true
            live.pupilOffset = CGVector(dx: 0, dy: 0.6)
            if let current = runningActivities.first, current.attributes.sessionStart == start {
                await push(to: current)
                // Red is showing; drop the standby one only after, so the island never goes blank.
                await endTimesUpActivities()
            } else {
                // The running activity is gone (e.g. dismissed); fall back to the red one.
                await ensureTimesUpActivity(start: start, scheduled: false)
            }
            return
        }

        let running = runningActivities
        if let current = running.first {
            // Keep exactly one.
            for extra in running.dropFirst() { await extra.end(nil, dismissalPolicy: .immediate) }
            if current.attributes.sessionStart != start {
                await current.end(nil, dismissalPolicy: .immediate)
            } else {
                await push(to: current)
                await ensureTimesUpActivity(start: start, scheduled: true)
                startAnimating()
                return
            }
        }
        startActivity(sessionStart: start)
        await ensureTimesUpActivity(start: start, scheduled: true)
        startAnimating()
    }

    private var runningActivities: [Activity<EyesAttributes>] {
        Activity<EyesAttributes>.activities.filter { !$0.attributes.isTimesUp }
    }

    private var timesUpActivities: [Activity<EyesAttributes>] {
        Activity<EyesAttributes>.activities.filter { $0.attributes.isTimesUp }
    }

    /// The system can't be asked to update the running activity while the app is suspended, so a
    /// second, always-red activity is scheduled to start at the end time. The system starts it on
    /// its own (with a silent alert that lights the island); its sound comes from the notifications.
    /// `scheduled == false` means time is already up, so it is started right away if missing.
    private func ensureTimesUpActivity(start: Date, scheduled: Bool) async {
        let existing = timesUpActivities
        let matching = existing.first { $0.attributes.sessionStart == start }
        if let matching {
            for extra in existing where extra.id != matching.id { await extra.end(nil, dismissalPolicy: .immediate) }
            // Already there for this end time (or already started): leave it alone.
            if !scheduled || timesUpScheduledFor == endDate { return }
        }
        await endTimesUpActivities()

        let attributes = EyesAttributes(sessionStart: start, isTimesUp: true)
        var state = EyesAttributes.ContentState.make(redLimitSeconds: totalSeconds)
        state.pupilOffset = CGVector(dx: 0, dy: 0.6)
        state.finished = true
        // Highest relevance so it takes the main island slot over the running one.
        let content = ActivityContent(state: state, staleDate: nil, relevanceScore: 100)
        do {
            if scheduled, let end = endDate, end > .now {
                // Scheduled starts need iOS 26; older systems rely on the stale date alone.
                guard #available(iOS 26.0, *) else { return }
                let alert = AlertConfiguration(
                    title: LocalizedStringResource(String.LocalizationValue(L("Time's up!"))),
                    body: LocalizedStringResource(String.LocalizationValue(L("Your eyes are red. 👀"))),
                    sound: .named("silence.wav")
                )
                timesUpHandle = try Activity.request(
                    attributes: attributes, content: content, pushType: nil,
                    style: .standard, alertConfiguration: alert,
                    // Starts a little early: the system needs a moment to present the alert, and this
                    // way the red eyes land together with the notification sound.
                    start: max(.now.addingTimeInterval(1), end.addingTimeInterval(-EyeStyle.timesUpLead))
                )
                timesUpScheduledFor = end
            } else {
                timesUpHandle = try Activity.request(attributes: attributes, content: content, pushType: nil)
            }
        } catch {
            Self.log.error("time's-up activity request failed: \(String(describing: error), privacy: .public)")
            activitiesEnabled = authorization.areActivitiesEnabled
        }
    }

    /// Ends every "time's up" activity, including the pending one we hold a handle to.
    private func endTimesUpActivities() async {
        for activity in timesUpActivities { await activity.end(nil, dismissalPolicy: .immediate) }
        if let handle = timesUpHandle { await handle.end(nil, dismissalPolicy: .immediate) }
        timesUpHandle = nil
        timesUpScheduledFor = nil
    }

    /// Keep animating briefly while iOS lets the process run, then settle on a calm frame.
    func appDidEnterBackground() {
        guard !animationTasks.isEmpty, backgroundTaskID == .invalid else { return }
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            Task { @MainActor in await self?.finishBackground() }
        }
        graceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(EyeStyle.backgroundGrace))
            guard !Task.isCancelled else { return }
            await self?.finishBackground()
        }
    }

    // MARK: Private

    /// Schedules the end-of-timer notification and, if the app is still foregrounded, the growl.
    private func scheduleEnd() {
        endTask?.cancel()
        guard let end = endDate else { return }
        Task {
            await TimerNotifications.requestAuthorization()
            await TimerNotifications.schedule(at: end)
        }
        endTask = Task { [weak self] in
            let wait = end.timeIntervalSinceNow
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            guard !Task.isCancelled else { return }
            self?.timerDidEnd(at: end)
        }
    }

    /// The process was alive at the end time (foreground or background grace): hand the island over
    /// to the red activity. The sound is started inside `startIfNeeded` when the app is visible.
    private func timerDidEnd(at end: Date) {
        guard startDate != nil else { return }
        Task { await startIfNeeded() }
    }

    /// Back in the app with the alarm still unacknowledged: keep ringing until the user stops it
    /// (notification sounds are silenced while the app is in the foreground).
    private func resumeAlarmIfNeeded() {
        guard let end = endDate, Date.now >= end,
              Date.now.timeIntervalSince(end) < AlarmPlayer.maxDuration,
              UIApplication.shared.applicationState != .background else { return }
        AlarmPlayer.shared.startRepeating()
    }

    /// Call after the alarm sound or on/off setting changes so the background notifications match.
    func alarmSettingsChanged() {
        guard isRunning else { return }
        scheduleEnd()
    }

    private func startActivity(sessionStart: Date, isRetryAfterCleanup: Bool = false) {
        let attributes = EyesAttributes(sessionStart: sessionStart)
        live.redLimitSeconds = totalSeconds
        do {
            _ = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: live, staleDate: nil),
                pushType: nil
            )
            activityRetryTask?.cancel()
            activityRetryTask = nil
            activityError = nil
        } catch {
            // Typically `.visibility`: the app wasn't visible on the phone (iPhone Mirroring, locked).
            Self.log.error("Live Activity request failed: \(String(describing: error), privacy: .public)")
            activitiesEnabled = authorization.areActivitiesEnabled
            activityError = String(describing: error)
            // Too many activities left over from earlier timers: clear them all and try once more.
            if !isRetryAfterCleanup,
               let authError = error as? ActivityAuthorizationError,
               authError == .targetMaximumExceeded || authError == .globalMaximumExceeded {
                Task {
                    await endAll()
                    for activity in Activity<EyesAttributes>.activities { await activity.end(nil, dismissalPolicy: .immediate) }
                    startActivity(sessionStart: sessionStart, isRetryAfterCleanup: true)
                    if !runningActivities.isEmpty {
                        await ensureTimesUpActivity(start: sessionStart, scheduled: true)
                        startAnimating()
                    }
                }
                return
            }
            scheduleActivityRetry()
        }
    }

    /// Keeps trying for a minute so the island eyes appear as soon as the system allows it.
    private func scheduleActivityRetry() {
        guard activityRetryTask == nil else { return }
        activityRetryTask = Task { [weak self] in
            for _ in 0..<30 {
                guard await self?.pause(2) == true else { break }
                guard let self, self.isRunning, self.islandEnabled, self.runningActivities.isEmpty else { break }
                await self.startIfNeeded()
                if !self.runningActivities.isEmpty { break }
            }
            self?.activityRetryTask = nil
        }
    }

    /// Every update re-passes the staleDate, otherwise the red switch is cleared.
    private func push(to activity: Activity<EyesAttributes>) async {
        live.redLimitSeconds = totalSeconds
        await activity.update(ActivityContent(
            state: live,
            staleDate: nil
        ))
    }

    private func pushLive() async {
        for activity in runningActivities { await push(to: activity) }
    }

    private func endAll() async {
        stopAnimating()
        await endTimesUpActivities()
        for activity in Activity<EyesAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    // MARK: Animation

    private func startAnimating() {
        guard animationTasks.isEmpty, islandEnabled else { return }
        // Updates are funnelled through one consumer so frames can't arrive out of order.
        let (stream, signal) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        updateSignal = signal
        animationTasks = [
            Task { [weak self] in for await _ in stream { await self?.pushLive() } },
            Task { [weak self] in await self?.glanceLoop() },
            Task { [weak self] in await self?.tiredLoop() },
            Task { [weak self] in await self?.sweepLoop() }
        ]
    }

    private func stopAnimating() {
        animationTasks.forEach { $0.cancel() }
        animationTasks.removeAll()
        updateSignal?.finish()
        updateSignal = nil
    }

    private func finishBackground() async {
        graceTask?.cancel()
        graceTask = nil
        // Freeze on a calm, open frame so the island never stays stuck mid-blink or mid-sweep.
        stopAnimating()
        live.isClosed = false
        live.lid = 0
        live.sweep = -1
        await pushLive()
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }

    private func cancelBackgroundGrace() {
        graceTask?.cancel()
        graceTask = nil
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }

    private func change(_ update: (inout EyesAttributes.ContentState) -> Void) {
        update(&live)
        updateSignal?.yield()
    }

    /// Returns false when cancelled.
    private func pause(_ seconds: Double) async -> Bool {
        do { try await Task.sleep(for: .seconds(seconds)); return true } catch { return false }
    }

    /// A natural blink: the lid slides down in steps, the eye stays shut for a beat (optionally
    /// looking somewhere new while it is hidden), then the lid slides back up.
    /// Returns false when cancelled.
    private func blink(changingGlance: Bool) async -> Bool {
        let steps = EyeStyle.blinkSteps
        for i in 1..<steps {
            change { $0.lid = Double(i) / Double(steps) }
            guard await pause(EyeStyle.blinkStepDuration) else { return false }
        }
        change { $0.isClosed = true; $0.lid = 0 }
        guard await pause(EyeStyle.blinkHold) else { return false }
        if changingGlance {
            change { $0.pupilOffset = EyesAttributes.ContentState.randomGlance(avoiding: $0.pupilOffset) }
            // Let the new position settle behind the closed lid before it opens.
            guard await pause(EyeStyle.blinkStepDuration) else { return false }
        }
        change { $0.isClosed = false; $0.lid = Double(steps - 1) / Double(steps) }
        for i in (0..<(steps - 1)).reversed() {
            guard await pause(EyeStyle.blinkStepDuration) else { return false }
            change { $0.lid = Double(i) / Double(steps) }
        }
        return true
    }

    /// Every few seconds: blink and look somewhere new.
    private func glanceLoop() async {
        while await pause(EyeStyle.glanceInterval) {
            if tiredActive { continue }
            guard await blink(changingGlance: true) else { return }
        }
    }

    /// Every few minutes: close the eyes slowly, hold, open slowly.
    private func tiredLoop() async {
        while await pause(EyeStyle.tiredInterval) {
            tiredActive = true
            defer { tiredActive = false }
            let steps = EyeStyle.tiredSteps
            for i in 1...steps {
                change { $0.lid = Double(i) / Double(steps) }
                guard await pause(EyeStyle.tiredStepDuration) else { return }
            }
            guard await pause(EyeStyle.tiredStepDuration * 2) else { return }
            for i in (0..<steps).reversed() {
                change { $0.lid = Double(i) / Double(steps) }
                guard await pause(EyeStyle.tiredStepDuration) else { return }
            }
        }
    }

    /// Expanded view: sweep to the opposite side, wait, sweep back, blink, repeat.
    private func sweepLoop() async {
        let steps = EyeStyle.sweepSteps
        while await pause(EyeStyle.sweepPause) {
            for i in 0...steps {
                change { $0.sweep = Double(i) / Double(steps) }
                guard await pause(EyeStyle.sweepStepDuration) else { return }
            }
            guard await pause(EyeStyle.sweepHold) else { return }
            for i in (0...steps).reversed() {
                change { $0.sweep = Double(i) / Double(steps) }
                guard await pause(EyeStyle.sweepStepDuration) else { return }
            }
            change { $0.sweep = -1 }
            guard await blink(changingGlance: false) else { return }
        }
    }
}
