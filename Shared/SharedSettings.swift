import Foundation

/// App Group `UserDefaults` wrapper shared by the app and the extension.
nonisolated enum SharedSettings {
    static let appGroup = "group.com.augustyang.eyesbuddy"

    private enum Key {
        static let totalSeconds = "timerTotalSeconds"
        static let islandEnabled = "islandEnabled"
        static let timerStart = "timerStart"
        static let onboardingDone = "onboardingDone"
        static let quickTimes = "quickTimes"
        static let alarmSound = "alarmSound"
        static let alarmSoundID = "alarmSoundID"
        static let languageCode = "languageCode"
        static let lastTimer = "lastTimerSeconds"
    }

    // Falls back to standard defaults if the group container is unavailable (e.g. unsigned builds).
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    static let defaultTotal = 5 * 60
    static let minTotal = 1
    /// A Live Activity is ended by the system after 8 h, so a timer can't be longer.
    static let maxTotal = 8 * 3600
    static let quickTimeCount = 7
    static let defaultQuickTimes = [60, 15 * 60, 30 * 60, 3600, 2 * 3600, 3 * 3600, 4 * 3600]

    static func clampTotal(_ seconds: Int) -> Int {
        min(max(seconds, minTotal), maxTotal)
    }

    /// Timer length in seconds.
    static var totalSeconds: Int {
        get {
            let v = defaults.integer(forKey: Key.totalSeconds)
            return v == 0 ? defaultTotal : clampTotal(v)
        }
        set { defaults.set(clampTotal(newValue), forKey: Key.totalSeconds) }
    }

    /// The seven quick-pick times (user editable).
    static var quickTimes: [Int] {
        get {
            guard let saved = defaults.array(forKey: Key.quickTimes) as? [Int],
                  saved.count == quickTimeCount else { return defaultQuickTimes }
            return saved.map(clampTotal)
        }
        set { defaults.set(newValue.map(clampTotal), forKey: Key.quickTimes) }
    }

    static var islandEnabled: Bool {
        get { defaults.object(forKey: Key.islandEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.islandEnabled) }
    }

    /// When the running timer was started; nil when no timer is running.
    static var timerStart: Date? {
        get { defaults.object(forKey: Key.timerStart) as? Date }
        set { defaults.set(newValue, forKey: Key.timerStart) }
    }

    static var alarmSoundEnabled: Bool {
        get { defaults.object(forKey: Key.alarmSound) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.alarmSound) }
    }

    /// Raw value of the chosen `AlarmSound`.
    static var alarmSoundID: String {
        get { defaults.string(forKey: Key.alarmSoundID) ?? "growl" }
        set { defaults.set(newValue, forKey: Key.alarmSoundID) }
    }

    /// Raw value of the chosen `AppLanguage`; "system" follows the device language.
    static var languageCode: String {
        get { defaults.string(forKey: Key.languageCode) ?? "system" }
        set { defaults.set(newValue, forKey: Key.languageCode) }
    }

    /// Length of the most recently started timer (for the "last timer" quick action).
    static var lastTimerSeconds: Int {
        get {
            let v = defaults.integer(forKey: Key.lastTimer)
            return v == 0 ? totalSeconds : clampTotal(v)
        }
        set { defaults.set(clampTotal(newValue), forKey: Key.lastTimer) }
    }

    static var onboardingDone: Bool {
        get { defaults.bool(forKey: Key.onboardingDone) }
        set { defaults.set(newValue, forKey: Key.onboardingDone) }
    }
}
