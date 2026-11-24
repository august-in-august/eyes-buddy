# Changelog

## Phases 0–7 (initial build)

- **Phase 0:** App target `eyes buddy` plus Widget Extension `EyesWidgetsExtension`; `Shared/` is a member of both. App Group `group.com.augustyang.eyesbuddy`, `NSSupportsLiveActivities = YES`. Both targets restricted to iPhone (ActivityKit has no macOS).
- **Phase 1:** `EyeView` (single renderer) and `EyeStyle` (tokens from the design canvas). `#Preview` shows open/closed × white/red at 14/24/60/90 pt and 5 pupil positions.
- **Phase 2:** `MainScreen` with in-app eyes flanking the island (pill on Dynamic Island devices, none otherwise), finger tracking per eye, 1.5 s release, tap-to-blink with haptic, timer, progress, sleep/wake button, settings.
- **Phase 3:** `EyesLiveActivity` with compact, minimal, expanded and Lock Screen views, plus previews for each × white/red × open/closed.
- **Phase 4:** `BlinkIntent` re-passes the same `staleDate` so red stays red.
- **Phase 5:** `SettingsScreen` (limit picker, island toggle, reset, about). DEBUG builds add a 1-minute limit.
- **Phase 6:** `EyesActivityController` keeps one activity, rolls over after 8 h, shows a banner when Live Activities are disabled.
- **Phase 7:** `OnboardingScreen` (3 pages), VoiceOver labels, Reduce Motion for tracking.

## Device feedback round 1

- Island eyes are now lively: every 5 s both eyes blink, change to a random shared direction while closed, and open. Every 5 min they close slowly and reopen (tiredness). Minimal uses the same state as compact.
- Expanded view: removed "Tap me to blink"; timer moved to the center region so the progress bar and "Red in / Limit" fit. Eyes run a sweep loop: left clockwise, right counter-clockwise to the opposite side (through the bottom), hold 3 s, sweep back, blink, repeat.
- Main screen: eyes moved below the island on an extended black pill (clear of the status bar); the full-screen eye layer no longer blocks taps (settings and sleep buttons work); sleep button no longer stretches; hint area cut to ~1/5 and content moved up.
- **Limitation:** Live Activities only change when the app pushes an update, so the animation runs only while the app is alive (foreground + 20 s after backgrounding, then it settles on an open, calm frame). Continuous animation while the app is closed needs APNs Live Activity push updates (a server), which is out of scope for v1.
- Cadence is in `EyeStyle` (glanceInterval, tiredInterval, sweep*). iOS may throttle frequent updates; the sweep is ~1 update/s while running.

## Concept change: timer app

- Set a timer, start it, and the eyes watch; they turn red at zero. The island and Lock Screen show "Time left" (countdown), "Ends at", and "Total".
- Alarm: a generated angry growl (`Resources/angry.wav`) plays in the app when time is up, and a local notification with the same sound covers the case where the app isn't running. Toggle in the page's Alarm section.
- Settings screen removed: its sections now sit below the Start/Stop button on the main page, which scrolls. Toggles use an accent track so the knob is visible.
- Timer length: 7 quick times (editable via "Edit times") plus Custom with alarm-style h / min / s wheels. Max 8 h (Live Activity limit), min 1 s.
- Buttons: Start timer / Stop timer / Stop alarm, plus Restart.

## Feedback round 2

- Alarm sounds: choose from Angry growl, Hunn!, Buzzer, Alarm clock, Siren, Chime (tap to select and preview). The alarm repeats every 5 s until stopped (max 5 min). In the background it is a series of 12 notifications 5 s apart (1 min); returning to the app resumes the ringing in-app. Sounds are synthesized by a script, not recorded, so swap the files in `Resources/` for better ones.
- App icon picker: Red (default), Light (the no-background icon on white), Mono (grayscale). All keep the black icon for dark mode and the grayscale one for tinted mode.
- Island blink is slower and stepped: lid slides down in 3 steps, stays shut 0.4 s while the eyes pick a new direction, then slides up in 3 steps. Tap-to-blink got half-lidded frames too.

## Feedback round 3

- **Island not turning red in the background:** the running activity relied on `staleDate` alone, which the system doesn't reliably re-render in the island while the app is suspended. A second, always-red "time's up" Live Activity is now scheduled (`Activity.request(..., start: endDate)`, iOS 26+) when a timer starts; the system starts it at the end time with the app suspended, with a higher relevance score so it takes the main island slot. Its alert is silent (`silence.wav`) because the sound comes from the notifications. If the app is alive at the end, or when you return, the old white activity is ended so only the red one remains. Unverified on device.
- **Quick actions:** long-press the app icon for three timers: last used, then the first two quick times (repeats skipped). Tapping one starts that timer. Rebuilt whenever a timer starts, quick times are edited, or the language changes.
- **Languages:** English, 简体中文, 日本語, 한국어, Español, Русский, हिन्दी, العربية (RTL), Deutsch, Français. Default follows the system language, English if unsupported (any Chinese maps to Simplified). Language menu in the main page and the onboarding top bar. Strings live in `Shared/Localizable.xcstrings`, looked up through `L()` so the in-app choice applies to the app, notifications and the Live Activity. Translations were written by me, not by a native-speaker review.
- Disabled string-catalog symbol generation (keys such as "Time's up" and "Time's up!" collided).

## Feedback round 4

- Removed the stale date from the running activity: a stale activity can be hidden from the island and the Mac menu bar, and it never re-rendered red anyway.
- The red "time's up" activity now starts `EyeStyle.timesUpLead` (2 s) before the end, because the system needs a moment to present its alert; it shows 0:00.
- If the app is alive at the end (foreground or the 20 s background grace) the running activity itself turns red and the standby one is dropped, so there is no gap. The standby one only covers a suspended app.
- Known limit: the Mac menu bar mirrors the running activity but apparently not the system-started red one, so with the app suspended it stays white at 0:00 until the app is opened.

## Feedback round 5

- Starting a timer through iPhone Mirroring left the island empty. Most likely ActivityKit refused the request (`visibility`: the app isn't visible on the phone) and the error was swallowed. The error is now logged (subsystem `com.guangyang.eyesbuddy`, category `activity`) and starting is retried every 2 s for up to a minute, and again whenever the app becomes active or the phone is unlocked. Unverified on device.

## Feedback round 6

- Island eyes missing even without iPhone Mirroring: suspected leftover scheduled "time's up" activities from earlier timers counting toward the per-app Live Activity limit (a pending activity may not be listed in `Activity.activities`). The scheduled activity is now ended through a stored handle; on a `targetMaximumExceeded` / `globalMaximumExceeded` error everything is cleared and the start is retried once.
- When the system refuses to start the island eyes, the reason is now shown in red on the main page (and logged), so the cause can be read instead of guessed.
- Overlapping `startIfNeeded` calls (scene change, unlock, timer end, retries) are merged so two runs can't both create an activity.
- The repeated end-of-timer notifications (12, 5 s apart) also reach an Apple Watch and a Mac; iOS forwards them. Reduce `TimerNotifications.repeatCount` if that is too much.

## Feedback round 7

- Island works after restarting the phone (the earlier failures were likely stuck system state, not the app).
- Alarm sounds: removed the angry growl and the buzzer; added three angry-cat sounds (converted from the supplied mp3s to 16-bit WAV, since notification sounds can't be mp3). Default is now "Hunn!"; a saved choice of the removed growl falls back to it.

## Release prep

- Category was set to Games; now Productivity. Home-screen name "Eyes Buddy". Portrait only on iPhone. `ITSAppUsesNonExemptEncryption = NO`.
- The widget extension required iOS 27.2 while the app supports 17.6; both are now 17.6.
- Added `PrivacyInfo.xcprivacy` (UserDefaults, reasons CA92.1 and 1C8F.1) to the app and the widget; no tracking, no collected data.
- Added `APP_STORE_LISTING.md` (10 languages, limits checked) and `PRIVACY.md`.

## 1.0.1 (build 2): launch crash on iOS 17

- **Crash:** every iOS 17 device crashed at launch with dyld `Symbol not found: _$s11ActivityKit0A5StyleO8standardyA2CmFWC`. `ActivityStyle` (used only by the iOS 26 scheduled-start call) shipped in iOS 26, but the SDK labels it `@available(iOS 16.1)`, so the compiler linked it strongly and the `#available(iOS 26)` guard could not help.
- **Fix:** ActivityKit is now weak-linked (`OTHER_LDFLAGS = -Wl,-weak_framework,ActivityKit` on the app target). Verified on the Release binary: `LC_LOAD_WEAK_DYLIB`, no strong ActivityKit symbol left. The scheduled red activity still runs only on iOS 26+.
- App and widget deployment targets are both iOS 17.0 (the widget was 17.6). Version 1.0.1, build 2.
- Not run on an iOS 17 device or simulator by me; no iOS 17 runtime is installed here.

## 1.0.1: iOS 17 scrolling and notification text

- **Main page didn't scroll on iOS 17:** the finger-tracking `DragGesture(minimumDistance: 0)` sat above the `ScrollView`, which blocks scrolling on iOS 17. Replaced by `TouchObserver`, a UIKit recognizer on the window that recognizes alongside every other gesture and never cancels touches. Checked on an iOS 27.2 simulator: page scrolls, taps work, pupils follow the touch. The iOS 17.5 simulator was only checked for launch (touch automation needs iOS 27+).
- **Notification text:** the body "Your eyes are red." is now "Tap to open the app and stop the timer." in all 10 languages (notification and the Live Activity alert).

## 1.0.1: crash when switching language on iOS 17

- **Crash:** iOS 17.5 crash reports show an array index-out-of-range inside SwiftUI's wheel `Picker` (hours/minutes/seconds), hit while the whole screen is rebuilt on a language change: UIKit asks the old wheel for a row after SwiftUI has dropped its copy of the rows.
- **Fix:** `TimeWheel` is now a `UIPickerView` with its own fixed data source (`UIViewRepresentable`), so there is no second copy of the rows to fall out of step. Used by the custom timer and the quick-time editor.
- Could not reproduce the original crash on the iOS 17.5 simulator (12 automated language switches in 4 s passed on both the old and the new wheel), so the exact trigger is unconfirmed. After the change, the same stress test passes on iOS 17.5, and on iOS 27 the wheel opens at the current value and scrolling it updates the timer.

## Tap the notification to stop the timer

- Tapping a "time's up" notification opens the app and stops the timer and the alarm (`stopTimerIfFinished`). It only acts on a timer that has run out, so a stale notification can't stop a newer timer. Works from a cold launch too (the tap is replayed once the controller exists; the notification delegate is installed in `didFinishLaunching`).
- Found while testing: the `didReceive` handler must run on the main thread. As a plain async method it crashed the app with "Call must be made on main thread" (the system's completion handler touches UIKit). It is now `@MainActor`.
- Relaunching with a finished timer no longer re-schedules the 12 end-of-timer notifications (they would have rung again a second after launch).
- Checked on the iOS 27.2 simulator: banner shows the new text, tapping it opens the app with "Not started", no further notifications arrive. Not run on iOS 17.

## Notification tap: now a setting

- New setting under Alarm: "When you tap the notification". Default: **open the app and stop it myself** (the alarm keeps ringing in the app until "Stop alarm"). Optional: **open the app and stop the timer automatically** (the behavior added just before). Stored as `SharedSettings.tapStopsTimer`, strings translated into all 10 languages.
- Checked on the iOS 27.2 simulator: with the default, tapping the banner opens the app in the finished state (red eyes, "Stop alarm"); with the automatic option the timer is reset to "Not started".

## Island blank on the iPhone 18 Pro simulator (not a bug in the app)

- On the iOS 27.2 simulator the Dynamic Island creates the activity but draws nothing in it (compact and expanded are both empty). The same Live Activity draws correctly on the Lock Screen of the same simulator, and the island previews in Xcode render. The build from Nov 9 (commit 5161544, the version that worked on a real iPhone 16) shows the identical blank island in this simulator, and a Release build behaves the same as Debug, so it is the simulator, not a regression.
- First use: iOS asks "Allow Live Activities from Eyes Buddy?" and later "Do you want to continue to allow ...?" (choose **Always Allow**). In the simulator these prompts appear on the Lock Screen. Until they are answered the activity is not shown in the island.
- Check the island on a real iPhone; use the simulator's Lock Screen and Xcode previews for the rest.

## Device feedback: red eyes lingering, island not tappable

- **Red eyes stayed in the island after the app was closed.** A Live Activity can only be ended by the app, so once the timer is up and the user opens the app, the app now ends the activity (the app screen keeps showing "time's up" and the alarm). If the user never opens the app, the red eyes stay (iOS removes them after 8 h at the latest) so the timer isn't missed.
- **Island not tappable after time's up.** The activity had no explicit open action, and in the expanded view / Lock Screen the eyes were blink buttons. Now the whole activity opens the app (`widgetURL` = `eyesbuddy://open`, registered as a URL scheme), and once time is up the eyes are links that open the app instead of blinking. The app handles the link like a notification tap, so the "When you tap the notification" setting applies (default: just open the app).
- Checked: URL scheme registered (iOS 17.5 simulator asks "Open in Eyes Buddy?"), builds, red expanded preview renders. Not verified on a real iPhone: the island does not render in the simulator.

### Not done / notes


- App icon added; accent color from the design is not set.
- Reduce Motion: the in-app tracking spring is disabled; the blink is still an instant swap, not a fade.
- Design uses Archivo; the app uses the system font (heavy weight) instead, as Archivo isn't bundled.
- Not tested on a real Dynamic Island device; the manual checklist in `DEVELOPMENT_PLAN.md` §7 is still open.
- "Privacy policy" row from the design is omitted (no URL yet).

### Blocked

- None.
