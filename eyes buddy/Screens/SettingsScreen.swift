import SwiftUI

struct SettingsScreen: View {
    @Environment(EyesActivityController.self) private var controller
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var controller = controller

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Settings")
                        .font(.system(size: 40, weight: .heavy))
                    Spacer()
                    Button("Done") { dismiss() }
                        .font(.system(size: 17, weight: .heavy))
                        .frame(minHeight: EyeStyle.minTapTarget)
                }
                .padding(.bottom, 16)

                section("Red-eye limit", note: "How long they watch before they get tired.") {
                    LimitPicker(seconds: Binding(
                        get: { controller.redLimitSeconds },
                        set: { value in Task { await controller.setRedLimit(value) } }
                    ))
                }

                section("Show eyes in Dynamic Island", note: "Long-press the island to open the big eyes.") {
                    Toggle("Show eyes in Dynamic Island", isOn: Binding(
                        get: { controller.islandEnabled },
                        set: { value in Task { await controller.setIslandEnabled(value) } }
                    ))
                    .labelsHidden()
                    .tint(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                section("Reset watching time", note: nil) {
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        Text("Currently watching for \(MainScreen.format(max(0, timeline.date.timeIntervalSince(controller.sessionStart))))")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(EyeStyle.secondaryText)
                    }
                    Button {
                        Task { await controller.resetSession() }
                    } label: {
                        Text("Reset watching time")
                            .font(.system(size: 17, weight: .heavy))
                            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                            .padding(.horizontal, 16)
                            .foregroundStyle(EyeStyle.redCopy)
                            .overlay(Rectangle().stroke(EyeStyle.redCopy, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }

                section("About", note: nil) {
                    row("Version", Self.version)
                    Text("Inspired by Googly Eyes for macOS")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(EyeStyle.secondaryText)
                }
            }
            .padding(EyeStyle.margin)
        }
        .foregroundStyle(.white)
        .background(EyeStyle.ground)
        .preferredColorScheme(.dark)
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

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.system(size: 17, weight: .semibold))
            Spacer()
            Text(value).font(.system(size: 17, weight: .semibold)).foregroundStyle(EyeStyle.secondaryText)
        }
    }

    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}

#Preview {
    SettingsScreen().environment(EyesActivityController())
}
