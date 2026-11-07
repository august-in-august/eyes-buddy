import Foundation

/// The alarm sounds the user can choose from. Files live in `Resources/`.
enum AlarmSound: String, CaseIterable, Identifiable {
    case growl, hunn, buzzer, beeps, siren, chime

    var id: String { rawValue }
    var fileName: String { "\(rawValue).wav" }

    var title: String {
        switch self {
        case .growl: "Angry growl"
        case .hunn: "Hunn!"
        case .buzzer: "Buzzer"
        case .beeps: "Alarm clock"
        case .siren: "Siren"
        case .chime: "Chime"
        }
    }

    var subtitle: String {
        switch self {
        case .growl: "Three grumpy growls"
        case .hunn: "A huffy grunt, like someone got annoyed"
        case .buzzer: "Harsh double buzz"
        case .beeps: "Classic digital beeps"
        case .siren: "Rising and falling wail"
        case .chime: "Two soft bells"
        }
    }

    static var selected: AlarmSound {
        AlarmSound(rawValue: SharedSettings.alarmSoundID) ?? .growl
    }
}
