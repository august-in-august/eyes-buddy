import SwiftUI
import UIKit

/// Chooses the home-screen icon. iOS shows its own confirmation when the icon changes.
/// Every choice keeps the black icon as its dark-mode variant.
struct IconPicker: View {
    private struct Choice: Identifiable {
        let iconName: String?          // nil = the primary icon
        let title: String
        let preview: String
        var id: String { iconName ?? "primary" }
    }

    private let choices = [
        Choice(iconName: nil, title: "Red", preview: "IconPreviewRed"),
        Choice(iconName: "AppIconLight", title: "Light", preview: "IconPreviewLight"),
        Choice(iconName: "AppIconMono", title: "Mono", preview: "IconPreviewMono")
    ]

    @State private var current = UIApplication.shared.alternateIconName

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ForEach(choices) { choice in
                Button { select(choice) } label: {
                    VStack(spacing: 8) {
                        Image(choice.preview)
                            .resizable()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(.white, lineWidth: current == choice.iconName ? 3 : 0)
                                    .padding(-4)
                            }
                            .padding(4)
                        Text(choice.title)
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(current == choice.iconName ? .white : EyeStyle.secondaryText)
                    }
                    .frame(minWidth: EyeStyle.minTapTarget, minHeight: EyeStyle.minTapTarget)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(choice.title) icon")
                .accessibilityAddTraits(current == choice.iconName ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
    }

    private func select(_ choice: Choice) {
        guard choice.iconName != current else { return }
        Task {
            do {
                try await UIApplication.shared.setAlternateIconName(choice.iconName)
                current = choice.iconName
            } catch {
                current = UIApplication.shared.alternateIconName
            }
        }
    }
}
