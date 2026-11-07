import SwiftUI

/// Red-limit chooser shared by Settings and Onboarding: presets plus a custom stepper.
struct LimitPicker: View {
    @Binding var seconds: Int
    @State private var customSelected = false

    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 1)]

    var body: some View {
        let presets = SharedSettings.presetLimits
        let isCustom = customSelected || !presets.contains(seconds)

        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(presets, id: \.self) { value in
                    chip(Self.label(value), selected: !isCustom && seconds == value) {
                        customSelected = false
                        seconds = value
                    }
                }
                chip("Custom", selected: isCustom) { customSelected = true }
            }
            .background(EyeStyle.rule)

            if isCustom {
                Stepper(value: $seconds, in: SharedSettings.minRedLimit...SharedSettings.maxRedLimit, step: 5 * 60) {
                    Text(Self.label(seconds))
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .heavy))
                .frame(maxWidth: .infinity, minHeight: EyeStyle.minTapTarget, alignment: .leading)
                .padding(.horizontal, 12)
                .foregroundStyle(selected ? Color.black : .white)
                .background(selected ? Color.white : EyeStyle.ground)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    static func label(_ seconds: Int) -> String {
        if seconds < 3600 { return "\(seconds / 60) min" }
        let hours = seconds / 3600, minutes = seconds % 3600 / 60
        return minutes == 0 ? "\(hours) h" : "\(hours) h \(minutes) min"
    }
}
