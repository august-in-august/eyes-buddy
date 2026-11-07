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

### Not done / notes

- App icon and accent color from the design are **not** added yet (design deliverable 1q needs exported PNGs).
- Reduce Motion: the in-app tracking spring is disabled; the blink is still an instant swap, not a fade.
- Design uses Archivo; the app uses the system font (heavy weight) instead, as Archivo isn't bundled.
- Not tested on a real Dynamic Island device; the manual checklist in `DEVELOPMENT_PLAN.md` §7 is still open.
- Bundle ID is still the Xcode placeholder (`devplaceholder.…`); set a real one before shipping.
- "Privacy policy" row from the design is omitted (no URL yet).

### Blocked

- None.
