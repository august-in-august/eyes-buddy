import ActivityKit
import AppIntents

/// Tapped from the expanded / Lock Screen eyes. Runs in the app's process.
nonisolated struct BlinkIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Blink"
    static var isDiscoverable: Bool { false }

    func perform() async throws -> some IntentResult {
        for activity in Activity<EyesAttributes>.activities {
            var state = activity.content.state
            // No stale date: a stale activity can be hidden from the island and the Mac menu bar.
            let stale: Date? = nil
            // Half-lidded frames either side of the closed one make the blink read as smooth.
            let originalLid = state.lid
            state.lid = 0.5
            await activity.update(ActivityContent(state: state, staleDate: stale))
            try? await Task.sleep(for: .milliseconds(150))
            state.isClosed = true
            state.lid = 0
            await activity.update(ActivityContent(state: state, staleDate: stale))
            try? await Task.sleep(for: .milliseconds(250))
            state.isClosed = false
            state.lid = 0.5
            await activity.update(ActivityContent(state: state, staleDate: stale))
            try? await Task.sleep(for: .milliseconds(150))
            state.lid = originalLid
            await activity.update(ActivityContent(state: state, staleDate: stale))
        }
        return .result()
    }
}
