import Foundation

/// App Group `UserDefaults` wrapper shared by the app and the extension.
nonisolated enum SharedSettings {
    static let appGroup = "group.com.augustyang.eyesbuddy"

    private enum Key {
        static let redLimitSeconds = "redLimitSeconds"
        static let islandEnabled = "islandEnabled"
        static let sessionStart = "sessionStart"
        static let onboardingDone = "onboardingDone"
    }

    // Falls back to standard defaults if the group container is unavailable (e.g. unsigned builds).
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    static let defaultRedLimit = 3600
    static let minRedLimit = 5 * 60
    static let maxRedLimit = 4 * 3600

    /// Preset limits in seconds (Settings picker). DEBUG builds add a 1-minute option.
    static var presetLimits: [Int] {
        var presets = [15 * 60, 30 * 60, 3600, 2 * 3600, 3 * 3600, 4 * 3600]
        #if DEBUG
        presets.insert(60, at: 0)
        #endif
        return presets
    }

    static var redLimitSeconds: Int {
        get {
            let v = defaults.integer(forKey: Key.redLimitSeconds)
            return v == 0 ? defaultRedLimit : v
        }
        set {
            #if DEBUG
            let lower = 60
            #else
            let lower = minRedLimit
            #endif
            defaults.set(min(max(newValue, lower), maxRedLimit), forKey: Key.redLimitSeconds)
        }
    }

    static var islandEnabled: Bool {
        get { defaults.object(forKey: Key.islandEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.islandEnabled) }
    }

    static var sessionStart: Date? {
        get { defaults.object(forKey: Key.sessionStart) as? Date }
        set { defaults.set(newValue, forKey: Key.sessionStart) }
    }

    static var onboardingDone: Bool {
        get { defaults.bool(forKey: Key.onboardingDone) }
        set { defaults.set(newValue, forKey: Key.onboardingDone) }
    }
}
