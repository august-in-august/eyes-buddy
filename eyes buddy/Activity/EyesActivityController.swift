import ActivityKit
import Foundation
import Observation

/// Owns the single Live Activity and the session the in-app timer reads.
/// `Activity<EyesAttributes>.activities` is the source of truth; never more than one runs.
@MainActor
@Observable
final class EyesActivityController {
    private(set) var sessionStart: Date
    private(set) var redLimitSeconds: Int
    private(set) var islandEnabled: Bool
    private(set) var activitiesEnabled: Bool

    private let authorization = ActivityAuthorizationInfo()
    @ObservationIgnored private var enablementTask: Task<Void, Never>?

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
                return
            }
        }
        start()
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

    // MARK: Private

    private func start() {
        let attributes = EyesAttributes(sessionStart: sessionStart)
        let state = EyesAttributes.ContentState.glance(redLimitSeconds: redLimitSeconds)
        do {
            _ = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: attributes.redDate(for: state)),
                pushType: nil
            )
        } catch {
            activitiesEnabled = authorization.areActivitiesEnabled
        }
    }

    /// Every update re-passes the staleDate, otherwise the red switch is cleared.
    private func push(to activity: Activity<EyesAttributes>) async {
        let state = EyesAttributes.ContentState.glance(redLimitSeconds: redLimitSeconds)
        await activity.update(ActivityContent(
            state: state,
            staleDate: activity.attributes.redDate(for: state)
        ))
    }

    private func endAll() async {
        for activity in Activity<EyesAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
