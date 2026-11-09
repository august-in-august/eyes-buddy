import Foundation

/// Languages the app is translated into, plus "follow the system".
/// The default is the system language; if that isn't supported, English.
nonisolated enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case en
    case zhHans = "zh-Hans"
    case ja, ko, es, ru, hi, ar, de, fr

    var id: String { rawValue }

    /// Every real language (everything except `.system`).
    static var concrete: [AppLanguage] { allCases.filter { $0 != .system } }

    /// Each language is shown in its own name so people can find theirs.
    var nativeName: String {
        switch self {
        case .system: "System"
        case .en: "English"
        case .zhHans: "简体中文"
        case .ja: "日本語"
        case .ko: "한국어"
        case .es: "Español"
        case .ru: "Русский"
        case .hi: "हिन्दी"
        case .ar: "العربية"
        case .de: "Deutsch"
        case .fr: "Français"
        }
    }

    var isRightToLeft: Bool { self == .ar }

    var locale: Locale { Locale(identifier: self == .system ? "en" : rawValue) }

    /// ISO language code used to match the system's preferred languages.
    private var languageCode: String { self == .zhHans ? "zh" : rawValue }

    // MARK: Selection

    /// What the user picked in the language menu (`.system` until they choose).
    static var choice: AppLanguage {
        get { AppLanguage(rawValue: SharedSettings.languageCode) ?? .system }
        set { SharedSettings.languageCode = newValue.rawValue }
    }

    /// The language actually in effect.
    static var current: AppLanguage {
        let picked = choice
        return picked == .system ? systemLanguage : picked
    }

    /// First of the system's preferred languages that we translate; English if none.
    static var systemLanguage: AppLanguage {
        for identifier in Locale.preferredLanguages {
            guard let code = Locale.Language(identifier: identifier).languageCode?.identifier else { continue }
            if let match = concrete.first(where: { $0.languageCode == code }) { return match }
        }
        return .en
    }

    /// The `.lproj` bundle holding this language's strings.
    fileprivate var bundle: Bundle {
        let language = self == .system ? AppLanguage.systemLanguage : self
        if let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return .main
    }
}

/// Looks a string up in the language chosen in the app (not just the system language).
nonisolated func L(_ key: String) -> String {
    AppLanguage.current.bundle.localizedString(forKey: key, value: key, table: nil)
}

/// Same, with `%@` placeholders filled in.
nonisolated func L(_ key: String, _ arguments: String...) -> String {
    String(format: L(key), locale: AppLanguage.current.locale, arguments: arguments)
}
