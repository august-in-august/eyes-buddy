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
                if phase == .active, onboardingDone {
                    Task { await controller.startIfNeeded() }
                }
            }
        }
    }
}
