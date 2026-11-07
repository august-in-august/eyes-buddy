import AVFoundation
import UserNotifications

/// Plays the chosen alarm sound while the app is in the foreground.
@MainActor
final class AlarmPlayer {
    static let shared = AlarmPlayer()

    /// The alarm repeats at this interval until the user stops it.
    static let repeatInterval = 5.0
    /// Safety net so a forgotten alarm doesn't ring forever.
    static let maxDuration = 5.0 * 60

    private var player: AVAudioPlayer?
    private var repeatTask: Task<Void, Never>?

    var isRinging: Bool { repeatTask != nil }

    /// Ring the selected sound now and every `repeatInterval` seconds until `stop()`.
    func startRepeating() {
        guard SharedSettings.alarmSoundEnabled, repeatTask == nil else { return }
        repeatTask = Task { [weak self] in
            let started = Date.now
            while !Task.isCancelled, Date.now.timeIntervalSince(started) < Self.maxDuration {
                self?.playOnce(AlarmSound.selected)
                try? await Task.sleep(for: .seconds(Self.repeatInterval))
            }
            self?.stop()
        }
    }

    /// Plays a sound once, for the picker.
    func preview(_ sound: AlarmSound) {
        stop()
        playOnce(sound)
    }

    func stop() {
        repeatTask?.cancel()
        repeatTask = nil
        guard player != nil else { return }
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func playOnce(_ sound: AlarmSound) {
        let name = (sound.fileName as NSString).deletingPathExtension
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return }
        // .playback so it is audible even with the silent switch on, like a timer should be.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
}

/// Local notifications cover the case where the app isn't running when time is up.
/// A notification sound plays once, so the repeats are scheduled as a series of notifications.
enum TimerNotifications {
    private static let identifierPrefix = "eyesbuddy.timer.end."
    /// 12 notifications, 5 s apart = one minute of repeats.
    private static let repeatCount = 12

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
        let sound = SharedSettings.alarmSoundEnabled
            ? UNNotificationSound(named: UNNotificationSoundName(AlarmSound.selected.fileName))
            : nil
        for index in 0..<repeatCount {
            let content = UNMutableNotificationContent()
            content.title = "Time's up!"
            content.body = "Your eyes are red. 👀"
            content.sound = sound
            let delay = max(1, date.timeIntervalSinceNow) + Double(index) * AlarmPlayer.repeatInterval
            try? await UNUserNotificationCenter.current().add(UNNotificationRequest(
                identifier: identifierPrefix + String(index),
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            ))
        }
    }

    static func cancel() {
        let ids = (0..<repeatCount).map { identifierPrefix + String($0) }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }
}
