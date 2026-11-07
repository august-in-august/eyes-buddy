import ActivityKit
import Foundation
import Observation
import UIKit

/// Owns the single Live Activity and the session the in-app timer reads.
/// `Activity<EyesAttributes>.activities` is the source of truth; never more than one runs.
///
/// Live Activities are snapshots: the island only changes when this process pushes an update.
/// The animation loops below therefore run only while the app is alive (foreground, plus a short
/// grace period after it goes to the background).
@MainActor
@Observable
final class EyesActivityController {
    private(set) var sessionStart: Date
    private(set) var redLimitSeconds: Int
    private(set) var islandEnabled: Bool
    private(set) var activitiesEnabled: Bool

    private let authorization = ActivityAuthorizationInfo()
    @ObservationIgnored private var enablementTask: Task<Void, Never>?

    // Animation
    @ObservationIgnored private var live: EyesAttributes.ContentState
    @ObservationIgnored private var animationTasks: [Task<Void, Never>] = []
    @ObservationIgnored private var updateSignal: AsyncStream<Void>.Continuation?
    @ObservationIgnored private var graceTask: Task<Void, Never>?
    @ObservationIgnored private var backgroundTaskID = UIBackgroundTaskIdentifier.invalid

    var redDate: Date { sessionStart.addingTimeInterval(TimeInterval(redLimitSeconds)) }

    init() {
        let now = Date.now
        if let stored = SharedSettings.sessionStart,
           now.timeIntervalSince(stored) < TimeInterval(EyeStyle.maxSessionSeconds) {
            sessionStart = stored
        } else {
            sessionStart = now
            SharedSettings.sessionStart = now
        }
        redLimitSeconds = SharedSettings.redLimitSeconds
        islandEnabled = SharedSettings.islandEnabled
        activitiesEnabled = authorization.areActivitiesEnabled
        live = .make(redLimitSeconds: SharedSettings.redLimitSeconds)

        enablementTask = Task { [weak self] in
            guard let updates = self?.authorization.activityEnablementUpdates else { return }
            for await enabled in updates {
                self?.activitiesEnabled = enabled
                if enabled { await self?.startIfNeeded() }
            }
        }
    }

    // MARK: Lifecycle

    /// Run on launch and whenever the scene becomes active.
    func startIfNeeded() async {
        cancelBackgroundGrace()
        activitiesEnabled = authorization.areActivitiesEnabled

        // The 8 h system limit ends the activity; roll over to a fresh session.
        if Date.now.timeIntervalSince(sessionStart) >= TimeInterval(EyeStyle.maxSessionSeconds) {
            sessionStart = .now
            SharedSettings.sessionStart = sessionStart
            await endAll()
        }

        guard islandEnabled, activitiesEnabled else { return }

        let running = Activity<EyesAttributes>.activities
        if let current = running.first {
            // Keep exactly one.
            for extra in running.dropFirst() { await extra.end(nil, dismissalPolicy: .immediate) }
            if current.attributes.sessionStart != sessionStart {
                await current.end(nil, dismissalPolicy: .immediate)
            } else {
                await push(to: current)
                startAnimating()
                return
            }
        }
        start()
        startAnimating()
    }

    func setRedLimit(_ seconds: Int) async {
        SharedSettings.redLimitSeconds = seconds
        redLimitSeconds = SharedSettings.redLimitSeconds
        for activity in Activity<EyesAttributes>.activities { await push(to: activity) }
    }

    func setIslandEnabled(_ enabled: Bool) async {
        islandEnabled = enabled
        SharedSettings.islandEnabled = enabled
        if enabled { await startIfNeeded() } else { await endAll() }
    }

    /// End the activity and start a new one with `sessionStart = now`.
    func resetSession() async {
        await endAll()
        sessionStart = .now
        SharedSettings.sessionStart = sessionStart
        await startIfNeeded()
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

    private func start() {
        let attributes = EyesAttributes(sessionStart: sessionStart)
        live.redLimitSeconds = redLimitSeconds
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
        live.redLimitSeconds = redLimitSeconds
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

    /// Every few seconds: blink, change where both eyes look while closed, open again.
    private func glanceLoop() async {
        while await pause(EyeStyle.glanceInterval) {
            change { $0.isClosed = true }
            guard await pause(EyeStyle.blinkDuration) else { return }
            change {
                $0.pupilOffset = EyesAttributes.ContentState.randomGlance(avoiding: $0.pupilOffset)
                $0.isClosed = false
            }
        }
    }

    /// Every few minutes: close the eyes slowly, hold, open slowly.
    private func tiredLoop() async {
        while await pause(EyeStyle.tiredInterval) {
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
            change { $0.isClosed = true }
            guard await pause(EyeStyle.blinkDuration) else { return }
            change { $0.isClosed = false }
        }
    }
}
