import UIKit

/// Home-screen quick actions (long-press the app icon): the most recent timer, then the first two
/// quick times. Tapping one starts that timer right away.
@MainActor
final class QuickActions {
    static let shared = QuickActions()

    private static let type = "com.guangyang.eyesbuddy.startTimer"
    private static let secondsKey = "seconds"

    /// Set once the app is up; the timer runs through it.
    weak var controller: EyesActivityController?
    private var pendingSeconds: Int?

    /// Rebuilds the items. Call after a timer starts, the quick times change, or the language changes.
    func refresh() {
        // Last timer first, then the quick times in order, skipping repeats.
        var seconds: [Int] = []
        for candidate in [SharedSettings.lastTimerSeconds] + SharedSettings.quickTimes where !seconds.contains(candidate) {
            seconds.append(candidate)
            if seconds.count == 3 { break }
        }
        UIApplication.shared.shortcutItems = seconds.enumerated().map { index, value in
            UIApplicationShortcutItem(
                type: Self.type,
                localizedTitle: L("Start %@", DurationFormat.short(value)),
                localizedSubtitle: index == 0 ? L("Last timer") : L("Quick time"),
                icon: UIApplicationShortcutIcon(systemImageName: index == 0 ? "clock.arrow.circlepath" : "timer"),
                userInfo: [Self.secondsKey: value as NSNumber]
            )
        }
    }

    /// Returns whether the item was one of ours.
    @discardableResult
    func handle(_ item: UIApplicationShortcutItem) -> Bool {
        guard item.type == Self.type,
              let seconds = (item.userInfo?[Self.secondsKey] as? NSNumber)?.intValue else { return false }
        pendingSeconds = seconds
        runPending()
        return true
    }

    /// Starts the requested timer as soon as the app is ready (a cold launch delivers the action first).
    func runPending() {
        guard let seconds = pendingSeconds, let controller else { return }
        pendingSeconds = nil
        // First-run users go through onboarding first instead.
        guard SharedSettings.onboardingDone else { return }
        Task { await controller.startTimer(seconds: seconds) }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // Cold launch from a quick action.
        if let item = options.shortcutItem { QuickActions.shared.handle(item) }
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    /// Quick action while the app is already running.
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(QuickActions.shared.handle(shortcutItem))
    }
}
