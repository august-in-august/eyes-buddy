import SwiftUI

@main struct MyApp: App {
    @State private var controller = EyesActivityController()
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
                    }
                }
            }
            .environment(controller)
            .task { if onboardingDone { await controller.startIfNeeded() } }
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
