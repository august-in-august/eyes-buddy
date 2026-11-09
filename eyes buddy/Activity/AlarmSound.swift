import Foundation

/// The alarm sounds the user can choose from. Files live in `Resources/`.
enum AlarmSound: String, CaseIterable, Identifiable {
    case growl, hunn, buzzer, beeps, siren, chime

    var id: String { rawValue }
    var fileName: String { "\(rawValue).wav" }

    var title: String {
        switch self {
        case .growl: L("Angry growl")
        case .hunn: L("Hunn!")
        case .buzzer: L("Buzzer")
        case .beeps: L("Alarm clock")
        case .siren: L("Siren")
        case .chime: L("Chime")
        }
    }

    var subtitle: String {
        switch self {
        case .growl: L("Three grumpy growls")
        case .hunn: L("A huffy grunt, like someone got annoyed")
        case .buzzer: L("Harsh double buzz")
        case .beeps: L("Classic digital beeps")
        case .siren: L("Rising and falling wail")
        case .chime: L("Two soft bells")
        }
    }

    static var selected: AlarmSound {
        AlarmSound(rawValue: SharedSettings.alarmSoundID) ?? .growl
    }
}
