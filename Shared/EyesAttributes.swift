import ActivityKit
import Foundation
import CoreGraphics

nonisolated struct EyesAttributes: ActivityAttributes {
    /// Static for the life of the activity.
    var sessionStart: Date

    struct ContentState: Codable, Hashable {
        /// True = blink frame.
        var isClosed: Bool
        /// Glance shared by both eyes in compact, minimal and Lock Screen (aligned, not mirrored).
        var pupilOffset: CGVector
        /// 0 = open ... 1 = fully closed. Used for the slow "tired" close every few minutes.
        var lid: Double
        /// Expanded view only: < 0 = resting, 0...1 = progress of the sweep to the opposite side.
        var sweep: Double
        var redLimitSeconds: Int

        static func make(redLimitSeconds: Int) -> ContentState {
            ContentState(isClosed: false, pupilOffset: randomGlance(), lid: 0, sweep: -1, redLimitSeconds: redLimitSeconds)
        }

        /// Random direction at any angle, medium to full travel.
        static func randomGlance(avoiding previous: CGVector? = nil) -> CGVector {
            for _ in 0..<8 {
                let angle = Double.random(in: 0..<(2 * .pi))
                let radius = Double.random(in: 0.55...0.95)
                let v = CGVector(dx: cos(angle) * radius, dy: sin(angle) * radius)
                guard let p = previous else { return v }
                if hypot(v.dx - p.dx, v.dy - p.dy) > 0.5 { return v }
            }
            return CGVector(dx: 0, dy: 0.7)
        }

        /// Pupil for the expanded view. Left eye sweeps clockwise, right eye counter-clockwise,
        /// each to the opposite side of its resting pose, passing through the bottom.
        func expandedOffset(rightEye: Bool) -> CGVector {
            let rest = EyeStyle.expandedRestPose
            let r = hypot(rest.dx, rest.dy)
            let base = atan2(rest.dy, rest.dx)            // screen coords: +angle = clockwise
            let start = rightEye ? Double.pi - base : base
            guard sweep >= 0 else {
                return CGVector(dx: rightEye ? -rest.dx : rest.dx, dy: rest.dy)
            }
            let angle = rightEye ? start - Double.pi * sweep : start + Double.pi * sweep
            return CGVector(dx: cos(angle) * r, dy: sin(angle) * r)
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
