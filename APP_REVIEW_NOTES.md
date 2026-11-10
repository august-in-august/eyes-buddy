# App Review reply (Guideline 2.1: Information Needed)

Paste the text in the box into **App Store Connect > App Review Information > Notes**, attach or link the screen recording, and resubmit. The same text works as the reply in the Resolution Center.

```
Hello App Review team,

Thank you for the review. Here is the information requested for Eyes Buddy - Timer.

1. SCREEN RECORDING
A screen recording captured on a physical iPhone running the latest iOS is attached/linked here: [LINK OR "attached"]. It starts with launching the app and shows the typical flow: onboarding, setting a timer, the Live Activity in the Dynamic Island and on the Lock Screen, the end-of-timer alarm, and the settings. The app has no account, no login, no user-generated content and no paid content, so none of those flows exist.

2. PURPOSE AND AUDIENCE
Eyes Buddy - Timer is a simple countdown timer for anyone who wants a friendlier way to watch the clock (studying, cooking, focus sessions, breaks). A pair of cartoon "googly eyes" watches the countdown from the Dynamic Island and the Lock Screen, and turns red with a repeating alarm sound when time is up. It solves the problem of a timer that is easy to ignore: the eyes stay visible while you use other apps. Suitable for all ages (4+).

3. HOW TO USE THE MAIN FEATURES (no login or sample files needed)
- Launch the app and go through the 3 onboarding pages; tap "Get started". Allow notifications when asked so the alarm can ring.
- On the main screen, drag a finger: the eyes follow it. Tap the eyes to blink.
- Under "Timer length", tap a quick time (e.g. "1 min") or "Custom" and use the hour/minute/second wheels. Tap "Start timer".
- Leave the app (Home Screen or another app). On iPhone 14 Pro or later the eyes and countdown show in the Dynamic Island; other iPhones show them on the Lock Screen. Long-press the island to expand it.
- When the time ends, the eyes turn red, a notification appears, and the chosen alarm sound repeats every 5 seconds until you open the app and tap "Stop alarm".
- Other features on the same page: edit the seven quick times ("Edit times"), choose the alarm sound, choose the app icon, choose the language, turn the Dynamic Island eyes on or off.
- Long-pressing the app icon on the Home Screen offers quick actions that start the last timer or a quick time.
- Live Activities must be allowed for the app (Settings > Eyes Buddy) for the island/Lock Screen display; the app shows a notice if they are off.

4. EXTERNAL SERVICES
None. The app uses no server, account system, analytics, advertising, payment processor, AI service or third-party SDK, and makes no network connections. It uses only Apple frameworks: SwiftUI, ActivityKit/WidgetKit (Live Activity), AppIntents, UserNotifications (local notifications) and AVFoundation (alarm sound). Settings are stored locally on the device.

5. REGIONAL DIFFERENCES
None. The app works the same in every region. The interface is localized into 10 languages (English, Simplified Chinese, Japanese, Korean, Spanish, Russian, Hindi, Arabic, German, French) and defaults to the device language, with English as the fallback. The Dynamic Island display needs iPhone 14 Pro or later; other iPhones show the same information on the Lock Screen.

6. REGULATED INDUSTRY / THIRD-PARTY MATERIAL
The app is not in a regulated industry. All artwork and code are our own. The alarm sounds are [original / licensed: STATE THE SOURCE AND LICENSE OF THE "ANGRY CAT" RECORDINGS HERE].

Thank you,
[Your name]
```

## Before you send it

1. **Fill in the two bracketed spots** (recording link, and the source/license of the cat sounds). If you cannot show you have the right to use the cat recordings, remove them from the app before resubmitting; point 6 of Apple's message asks about protected third-party material.
2. **Optional:** the About section says "Inspired by Googly Eyes for macOS". It is a plain credit, but if you want zero chance of an IP question, delete that line.
3. **Make sure the build you resubmit is the one you tested** on a physical device, with Live Activities and notifications allowed.

## Screen recording plan (about 90 seconds, on the iPhone)

Use Control Center > Screen Recording (turn the microphone off; device audio is recorded). Delete and reinstall the app first so onboarding shows.

1. Launch the app from the Home Screen: onboarding pages, language button, "Get started", allow notifications.
2. Main screen: drag a finger (eyes follow), tap the eyes (blink).
3. Scroll down: quick times, "Edit times", the wheels, alarm sounds (tap one to hear it), app icon, language menu.
4. Pick "1 min", tap "Start timer".
5. Go Home, show the eyes in the Dynamic Island, long-press to expand, then lock the phone and show the Lock Screen.
6. When the minute ends: red eyes, notification, alarm sound. Open the app and tap "Stop alarm".
7. Long-press the app icon to show the quick actions.

The screen recording shows the island, but not the alarm if the phone is muted or in a Focus; if that happens, also film the phone with a second device for a few seconds.
