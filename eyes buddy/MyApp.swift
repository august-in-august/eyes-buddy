import SwiftUI

@main struct MyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var controller = EyesActivityController()
    @State private var language = LanguageModel()
    @State private var onboardingDone = SharedSettings.onboardingDone
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if onboardingDone {
                    MainScreen()
                } else {
                    OnboardingScreen {
                        SharedSettings.onboardingDone = true
                        onboardingDone = true
                        QuickActions.shared.refresh()
                    }
                }
            }
            .environment(controller)
            .environment(language)
            .environment(\.locale, language.resolved.locale)
            .environment(\.layoutDirection, language.resolved.isRightToLeft ? .rightToLeft : .leftToRight)
            // Rebuild every screen when the language changes so all text is looked up again.
            .id(language.resolved)
            .task {
                QuickActions.shared.controller = controller
                QuickActions.shared.refresh()
                QuickActions.shared.runPending()
                if onboardingDone { await controller.startIfNeeded() }
            }
            .onChange(of: scenePhase) { _, phase in
                guard onboardingDone else { return }
                switch phase {
                case .active: Task { await controller.startIfNeeded() }
                case .background: controller.appDidEnterBackground()
                default: break
                }
            }
        }
    }
}
