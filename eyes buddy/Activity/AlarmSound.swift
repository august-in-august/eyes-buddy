import Foundation

/// The alarm sounds the user can choose from. Files live in `Resources/`.
enum AlarmSound: String, CaseIterable, Identifiable {
    case hunn, cat1, cat2, cat3, beeps, siren, chime

    var id: String { rawValue }
    var fileName: String { "\(rawValue).wav" }

    var title: String {
        switch self {
        case .hunn: L("Hunn!")
        case .cat1: L("Angry cat %@", "1")
        case .cat2: L("Angry cat %@", "2")
        case .cat3: L("Angry cat %@", "3")
        case .beeps: L("Alarm clock")
        case .siren: L("Siren")
        case .chime: L("Chime")
        }
    }

    var subtitle: String {
        switch self {
        case .hunn: L("A huffy grunt, like someone got annoyed")
        case .cat1, .cat2, .cat3: L("A very annoyed cat")
        case .beeps: L("Classic digital beeps")
        case .siren: L("Rising and falling wail")
        case .chime: L("Two soft bells")
        }
    }

    /// Falls back to "Hunn!" if the saved choice no longer exists (e.g. the removed growl).
    static var selected: AlarmSound {
        AlarmSound(rawValue: SharedSettings.alarmSoundID) ?? .hunn
    }
}
