import ActivityKit
import AppIntents

/// Tapped from the expanded / Lock Screen eyes. Runs in the app's process.
nonisolated struct BlinkIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Blink"
    static var isDiscoverable: Bool { false }

    func perform() async throws -> some IntentResult {
        for activity in Activity<EyesAttributes>.activities {
            var state = activity.content.state
            // Always pass the same staleDate so a red eye stays red.
            let stale = activity.attributes.redDate(for: state)
            state.isClosed = true
            await activity.update(ActivityContent(state: state, staleDate: stale))
            try? await Task.sleep(for: .milliseconds(180))
            state.isClosed = false
            await activity.update(ActivityContent(state: state, staleDate: stale))
        }
        return .result()
    }
}
