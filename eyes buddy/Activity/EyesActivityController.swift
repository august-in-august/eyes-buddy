import ActivityKit
import Foundation
import Observation
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

    private let authorization = ActivityAuthorizationInfo()
    @ObservationIgnored private var enablementTask: Task<Void, Never>?
    @ObservationIgnored private var endTask: Task<Void, Never>?
    /// True while the slow tired close runs, so the normal blink doesn't fight over the lid.
    @ObservationIgnored private var tiredActive = false

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
        startDate = .now
        SharedSettings.timerStart = startDate
        scheduleEnd()
        await startIfNeeded()
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
        for activity in Activity<EyesAttributes>.activities { await push(to: activity) }
    }

    func setIslandEnabled(_ enabled: Bool) async {
        islandEnabled = enabled
        SharedSettings.islandEnabled = enabled
        await startIfNeeded()
    }

    // MARK: Lifecycle

    /// Run on launch and whenever the scene becomes active: makes the activity match the timer.
    func startIfNeeded() async {
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

        let running = Activity<EyesAttributes>.activities
        if let current = running.first {
            // Keep exactly one.
            for extra in running.dropFirst() { await extra.end(nil, dismissalPolicy: .immediate) }
            if current.attributes.sessionStart != start {
                await current.end(nil, dismissalPolicy: .immediate)
            } else {
                await push(to: current)
                startAnimating()
                return
            }
        }
        startActivity(sessionStart: start)
        startAnimating()
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

    private func timerDidEnd(at end: Date) {
        // If the app was suspended and only just woke up, the notification already made the noise.
        guard UIApplication.shared.applicationState == .active,
              Date.now.timeIntervalSince(end) < 2 else { return }
        AlarmPlayer.shared.startRepeating()
    }

    /// Back in the app with the alarm still unacknowledged: keep ringing until the user stops it
    /// (notification sounds are silenced while the app is in the foreground).
    private func resumeAlarmIfNeeded() {
        guard let end = endDate, Date.now >= end,
              Date.now.timeIntervalSince(end) < AlarmPlayer.maxDuration else { return }
        AlarmPlayer.shared.startRepeating()
    }

    /// Call after the alarm sound or on/off setting changes so the background notifications match.
    func alarmSettingsChanged() {
        guard isRunning else { return }
        scheduleEnd()
    }

    private func startActivity(sessionStart: Date) {
        let attributes = EyesAttributes(sessionStart: sessionStart)
        live.redLimitSeconds = totalSeconds
        do {
            _ = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: live, staleDate: attributes.redDate(for: live)),
                pushType: nil
            )
        } catch {
            activitiesEnabled = authorization.areActivitiesEnabled
        }
    }

    /// Every update re-passes the staleDate, otherwise the red switch is cleared.
    private func push(to activity: Activity<EyesAttributes>) async {
        live.redLimitSeconds = totalSeconds
        await activity.update(ActivityContent(
            state: live,
            staleDate: activity.attributes.redDate(for: live)
        ))
    }

    private func pushLive() async {
        for activity in Activity<EyesAttributes>.activities { await push(to: activity) }
    }

    private func endAll() async {
        stopAnimating()
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
