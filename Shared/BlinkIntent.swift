import ActivityKit
import AppIntents

/// Tapped from the expanded / Lock Screen eyes. Runs in the app's process.
nonisolated struct BlinkIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Blink"
    static var isDiscoverable: Bool { false }

    func perform() async throws -> some IntentResult {
        for activity in Activity<EyesAttributes>.activities {
            let limit = activity.content.state.redLimitSeconds
            // Always pass the same staleDate so a red eye stays red.
            let stale = activity.attributes.redDate(limitSeconds: limit)
            await activity.update(ActivityContent(
                state: .glance(isClosed: true, redLimitSeconds: limit),
                staleDate: stale
            ))
            try? await Task.sleep(for: .milliseconds(180))
            await activity.update(ActivityContent(
                state: .glance(redLimitSeconds: limit),
                staleDate: stale
            ))
        }
        return .result()
    }
}
