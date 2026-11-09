import SwiftUI
import Observation

/// The language the app UI uses. Defaults to the system language (English if that isn't supported).
@MainActor
@Observable
final class LanguageModel {
    private(set) var choice: AppLanguage

    /// The concrete language in effect right now.
    var resolved: AppLanguage { choice == .system ? AppLanguage.systemLanguage : choice }

    init() { choice = AppLanguage.choice }

    func select(_ language: AppLanguage) {
        choice = language
        AppLanguage.choice = language
    }
}

/// A button that opens a menu of languages, each in its own name.
struct LanguageMenu: View {
    enum Style { case row, compact }

    @Environment(LanguageModel.self) private var language
    @Environment(EyesActivityController.self) private var controller
    var style: Style = .row

    var body: some View {
        Menu {
            ForEach(AppLanguage.allCases) { option in
                Button {
                    language.select(option)
                    controller.languageChanged()
                } label: {
                    if option == language.choice {
                        Label(title(for: option), systemImage: "checkmark")
                    } else {
                        Text(title(for: option))
                    }
                }
            }
        } label: {
            switch style {
            case .row:
                HStack {
                    Image(systemName: "globe")
                    Text(currentName).font(.system(size: 17, weight: .heavy))
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 13, weight: .heavy))
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 52)
                .foregroundStyle(.white)
                .overlay(Rectangle().stroke(.white, lineWidth: 2))
                .contentShape(Rectangle())
            case .compact:
                HStack(spacing: 6) {
                    Image(systemName: "globe")
                    Text(language.resolved.nativeName).font(.system(size: 13, weight: .heavy))
                }
                .foregroundStyle(.white)
                .frame(minHeight: EyeStyle.minTapTarget)
            }
        }
        .accessibilityLabel(L("Language"))
    }

    /// "System default (日本語)" for the system option, the language's own name otherwise.
    private func title(for option: AppLanguage) -> String {
        option == .system
            ? "\(L("System default")) (\(AppLanguage.systemLanguage.nativeName))"
            : option.nativeName
    }

    private var currentName: String { title(for: language.choice) }
}
