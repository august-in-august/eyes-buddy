import SwiftUI

/// What used to be the Settings screen, now laid out on the main page below the timer button.
struct SettingsSections: View {
    @Environment(EyesActivityController.self) private var controller
    @State private var alarmSound = SharedSettings.alarmSoundEnabled
    @State private var selectedSound = AlarmSound.selected

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            section("Timer length", note: "Pick how long the eyes keep watch before they turn red.") {
                TimerPicker(seconds: Binding(
                    get: { controller.totalSeconds },
                    set: { value in Task { await controller.setTotal(value) } }
                ))
            }

            section("Show eyes in Dynamic Island", note: "Long-press the island to open the big eyes.") {
                toggle("Dynamic Island eyes", isOn: Binding(
                    get: { controller.islandEnabled },
                    set: { value in Task { await controller.setIslandEnabled(value) } }
                ))
            }

            section("Alarm", note: "Repeats every 5 seconds until you stop it.") {
                toggle("Alarm sound", isOn: $alarmSound)
                    .onChange(of: alarmSound) { _, value in
                        SharedSettings.alarmSoundEnabled = value
                        controller.alarmSettingsChanged()
                    }
                if alarmSound {
                    soundList
                }
            }

            section("App icon", note: "The dark-mode icon is always the black one.") {
                IconPicker()
            }

            section("About", note: nil) {
                HStack {
                    Text("Version").font(.system(size: 17, weight: .semibold))
                    Spacer()
                    Text(Self.version)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(EyeStyle.secondaryText)
                }
                Text("Inspired by Googly Eyes for macOS")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(EyeStyle.secondaryText)
            }
        }
    }

    private func section<Content: View>(_ title: String, note: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle().fill(EyeStyle.rule).frame(height: 2)
            Text(title)
                .font(.system(size: 11, weight: .heavy))
                .kerning(0.9)
                .textCase(.uppercase)
                .foregroundStyle(EyeStyle.secondaryText)
            if let note {
                Text(note)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(EyeStyle.secondaryText)
            }
            content()
        }
        .padding(.bottom, 24)
    }

    /// Tap a sound to choose it and hear it once.
    private var soundList: some View {
        VStack(spacing: 1) {
            ForEach(AlarmSound.allCases) { sound in
                let selected = sound == selectedSound
                Button {
                    selectedSound = sound
                    SharedSettings.alarmSoundID = sound.rawValue
                    AlarmPlayer.shared.preview(sound)
                    controller.alarmSettingsChanged()
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sound.title).font(.system(size: 17, weight: .heavy))
                            Text(sound.subtitle)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(selected ? Color.black.opacity(0.6) : EyeStyle.secondaryText)
                        }
                        Spacer()
                        Image(systemName: selected ? "speaker.wave.2.fill" : "speaker.wave.1")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 60)
                    .foregroundStyle(selected ? Color.black : .white)
                    .background(selected ? Color.white : EyeStyle.ground)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .background(EyeStyle.rule)
    }

    /// The accent track keeps the white knob visible in both states.
    private func toggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title).font(.system(size: 17, weight: .semibold))
        }
        .tint(EyeStyle.accent)
        .frame(minHeight: EyeStyle.minTapTarget)
    }

    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}
