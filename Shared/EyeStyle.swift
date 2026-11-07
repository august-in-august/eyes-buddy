import SwiftUI

/// Design tokens shared by the app and the Live Activity.
/// Values come from the "Googly Eyes" design canvas (Modernist system, 1r style guide).
nonisolated enum EyeStyle {
    // MARK: Colors
    static let island = Color.black
    static let pupil = Color.black
    static let sclera = Color.white
    static let scleraTiring = Color(hex: 0xFFF2EF)
    static let scleraRed = Color(hex: 0xFFC4B8)
    /// "Tired red", the single accent.
    static let accent = Color(hex: 0xEC3013)
    static let rimTiring = Color(hex: 0xFF9783)
    static let lidTiring = Color(hex: 0xFFC4B8)
    static let lashWhite = Color(hex: 0x201E1D)
    static let lashRed = Color(hex: 0x7C1405)
    static let shutWhite = Color(hex: 0xD7D3D3)
    static let shutRed = Color(hex: 0xFF9783)
    /// Copy on dark when red (red ramp 400).
    static let redCopy = Color(hex: 0xFF9783)

    // App neutrals
    static let ground = Color(hex: 0x121111)
    static let surface = Color(hex: 0x2D2B2B)
    static let rule = Color(hex: 0x444141)
    static let secondaryText = Color(hex: 0xBAB6B6)

    // MARK: Eye geometry (fractions of the diameter)
    static let pupilRatio = 0.45
    static let maxTravel = 0.235
    static let highlightRatio = 0.28          // of the pupil
    static let highlightMinDiameter = 30.0    // below this the highlight is dropped
    static let redRimRatio = 0.07
    static let tiringRimRatio = 0.035
    static let redLidRatio = 0.30
    static let tiringLidRatio = 0.16
    static let lashRatio = 0.07
    static let lashMinWidth = 1.5
    static let minRim = 1.0

    // MARK: Dynamic Island geometry (points)
    static let islandSize = CGSize(width: 126, height: 37)
    static let islandTop = 11.0
    /// `safeAreaInsets.top` at or above this means the device has a Dynamic Island.
    static let islandSafeAreaTop = 59.0

    // MARK: Eye sizes
    static let compactEye = 24.0
    static let minimalEye = 27.0
    static let expandedEye = 60.0
    static let lockScreenEye = 56.0
    static let appEye = 44.0
    /// Gap between the island's edge and each in-app eye, and pill padding around the eyes.
    static let appEyeGap = 6.0
    static let appPillPadding = 6.0
    /// Gap between the two eyes on devices without a Dynamic Island.
    static let appEyePairGap = 14.0
    static let minTapTarget = 44.0

    // MARK: Layout
    static let spacing = 4.0
    static let margin = 20.0

    // MARK: Limits
    static let maxSessionSeconds = 8 * 3600
}

nonisolated extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
