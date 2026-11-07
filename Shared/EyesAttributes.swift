import ActivityKit
import Foundation
import CoreGraphics

nonisolated struct EyesAttributes: ActivityAttributes {
    /// Static for the life of the activity.
    var sessionStart: Date

    struct ContentState: Codable, Hashable {
        /// True = blink frame.
        var isClosed: Bool
        /// Normalized glance. `dx` is positive toward the center of the island; the trailing eye mirrors it.
        var pupilOffset: CGVector
        var redLimitSeconds: Int

        static func glance(isClosed: Bool = false, redLimitSeconds: Int) -> ContentState {
            ContentState(
                isClosed: isClosed,
                pupilOffset: CGVector(dx: .random(in: 0.4...0.9), dy: .random(in: 0.2...0.5)),
                redLimitSeconds: redLimitSeconds
            )
        }
    }

    /// The moment the eyes turn red. Passed as `staleDate` on every start and update.
    func redDate(limitSeconds: Int) -> Date {
        sessionStart.addingTimeInterval(TimeInterval(limitSeconds))
    }

    func redDate(for state: ContentState) -> Date {
        redDate(limitSeconds: state.redLimitSeconds)
    }

    /// Range for `Text(timerInterval:)`, covering the 8 h life of an activity.
    var watchingRange: ClosedRange<Date> {
        sessionStart...sessionStart.addingTimeInterval(TimeInterval(EyeStyle.maxSessionSeconds))
    }

    func limitRange(for state: ContentState) -> ClosedRange<Date> {
        sessionStart...max(sessionStart.addingTimeInterval(1), redDate(for: state))
    }
}
