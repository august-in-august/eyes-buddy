import AVFoundation
import UserNotifications

/// Plays the "time's up" growl while the app is in the foreground.
@MainActor
final class AlarmPlayer {
    static let shared = AlarmPlayer()
    private var player: AVAudioPlayer?
    private var stopTask: Task<Void, Never>?

    func play() {
        guard SharedSettings.alarmSoundEnabled,
              let url = Bundle.main.url(forResource: "angry", withExtension: "wav") else { return }
        // .playback so it is audible even with the silent switch on, like a timer should be.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.numberOfLoops = 3
        player?.play()
        stopTask?.cancel()
        stopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }

    func stop() {
        stopTask?.cancel()
        guard player != nil else { return }
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

/// A local notification covers the case where the app isn't running when time is up.
enum TimerNotifications {
    private static let identifier = "eyesbuddy.timer.end"

    /// In the foreground the app plays the sound itself, so the banner is suppressed.
    nonisolated final class ForegroundDelegate: NSObject, UNUserNotificationCenterDelegate {
        func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            willPresent notification: UNNotification
        ) async -> UNNotificationPresentationOptions { [] }
    }

    static let delegate = ForegroundDelegate()

    static func install() {
        UNUserNotificationCenter.current().delegate = delegate
    }

    static func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    static func schedule(at date: Date) async {
        cancel()
        let content = UNMutableNotificationContent()
        content.title = "Time's up!"
        content.body = "Your eyes are red. 👀"
        if SharedSettings.alarmSoundEnabled {
            content.sound = UNNotificationSound(named: UNNotificationSoundName("angry.wav"))
        }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        )
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
