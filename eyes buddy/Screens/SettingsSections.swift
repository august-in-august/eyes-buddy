import SwiftUI

/// What used to be the Settings screen, now laid out on the main page below the timer button.
struct SettingsSections: View {
    @Environment(EyesActivityController.self) private var controller
    @State private var alarmSound = SharedSettings.alarmSoundEnabled

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

            section("Alarm", note: "A grumpy growl when time is up.") {
                toggle("Angry sound", isOn: $alarmSound)
                    .onChange(of: alarmSound) { _, value in SharedSettings.alarmSoundEnabled = value }
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
