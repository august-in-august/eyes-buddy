import CoreGraphics

/// Touch point → pupil offset.
enum FingerTracker {
    /// Distance at which the pupil reaches full travel.
    private static let fullTravelDistance: CGFloat = 90

    /// Each eye is computed separately so the pair converges naturally on a nearby touch.
    static func offset(from eyeCenter: CGPoint, to touch: CGPoint) -> CGVector {
        let dx = touch.x - eyeCenter.x
        let dy = touch.y - eyeCenter.y
        let distance = (dx * dx + dy * dy).squareRoot()
        guard distance > 0.5 else { return .zero }
        let strength = min(1, distance / fullTravelDistance)
        return CGVector(dx: dx / distance * strength, dy: dy / distance * strength)
    }
}
