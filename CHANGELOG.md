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

### Not done / notes


- App icon added; accent color from the design is not set.
- Reduce Motion: the in-app tracking spring is disabled; the blink is still an instant swap, not a fade.
- Design uses Archivo; the app uses the system font (heavy weight) instead, as Archivo isn't bundled.
- Not tested on a real Dynamic Island device; the manual checklist in `DEVELOPMENT_PLAN.md` §7 is still open.
- "Privacy policy" row from the design is omitted (no URL yet).

### Blocked

- None.
