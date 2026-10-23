# Architecture

Sippy is a Swift Package (`native/`) with three targets:

| Target | Kind | Contents |
|---|---|---|
| `SippyCore` | library | Plain-Foundation logic: settings, intake log, stats, units, scheduler. No UI. |
| `Sippy` | executable | The app: AppKit menu bar and windows, SwiftUI views, the overlay, audio. |
| `SippyChecks` | executable | Logic checks for `SippyCore` (see [Checks](#checks)). |

Requires macOS 13 (Swift Charts, `SMAppService`, `ImageRenderer`). Language mode is Swift 5.

## The pieces

```
                 ┌──────────────┐  every 5 s   ┌───────────────────┐
                 │ Reminder-    │◄────tick─────│ Timer (RunLoop)   │
                 │ Scheduler    │              └───────────────────┘
                 └──────┬───────┘
          due & not held│ onFire
                 ┌──────▼───────┐   answer(ml:)   ┌──────────────┐
 menu bar ──────►│  AppModel    │◄────────────────│ Overlay-     │──► NSPanel + ReminderView
 (AppDelegate)   │ (Observable) │────show()──────►│ Controller   │      └ CharacterView (sprites / drawn)
 dashboard ─────►│              │                 └──────┬───────┘
 settings  ─────►│              │──► AudioPlayer ◄───────┘ music, appear.mp3, cheer.mp3
                 └──┬────────┬──┘
                    │        │
           SettingsStore   IntakeLog ──► WaterStats / Amounts (display units)
           (UserDefaults)  (intake.json)
```

### `SippyCore`

- **`AppSettings` / `SettingsStore`**: every preference in one `Codable` struct, saved as JSON
  under the `UserDefaults` key `sippy.settings.v1`. `clamped()` keeps values in safe ranges
  (e.g. an interval of 0 can't cause a reminder storm). Decoding is field-by-field, so settings
  from older builds still load.
- **`IntakeLog`**: every drink as `{date, ml}` in `intake.json`, sorted, written atomically.
  It also reads the original format (a bare array of timestamps, one per glass) and migrates
  each entry to 250 ml.
- **`WaterStats`**: totals per day, streak (consecutive days at goal; today only counts once
  reached, so an unfinished day doesn't break yesterday's streak), and the last N days.
- **`Amounts`**: converts millilitres into the user's units. Glass mode says "3 of 8 glasses";
  bottle mode says "1.2 of 2.5 L" and "2½ bottles". It also produces the answer buttons
  (`DrinkOption`s): one glass, or sips / ¼ / ½ / whole bottle.
- **`ReminderScheduler`**: holds a single wall-clock deadline (`nextFire`) and checks it every
  5 seconds. Because it compares against the clock rather than counting down, a reminder that
  came due while the Mac slept fires on wake instead of drifting. A `shouldHold` closure lets
  the app hold a due reminder (paused, screen locked, reminder already showing) without losing it.
- **`ActiveHours`**: the optional daily window (minutes after midnight; `from > to` wraps past
  midnight). `ReminderPlan.fireDate` schedules each reminder after the interval or snooze, or at the
  window's next opening if it would land outside. The app also re-checks when a reminder comes due.

### `Sippy` (app)

- **`main.swift`**: starts `NSApplication` with the `.accessory` policy (menu bar only, no Dock
  icon). It also handles the `--render-previews` dev flag.
- **`AppDelegate`**: the status item (a hand-drawn template glass icon), its menu (refreshed in
  `menuWillOpen`), first-launch hello, and the Dashboard/Settings windows (`NSWindow` hosting SwiftUI).
- **`AppModel`**: the one `ObservableObject` everything shares. It owns settings, entries, the
  scheduler, the overlay and audio. It tracks **screen lock** (`com.apple.screenIsLocked`/
  `Unlocked`) and **display sleep** separately, holds reminders while either is on, and on
  return pushes any overdue reminder out by 60 seconds.
- **`OverlayController`**: the reminder itself:
  - A borderless, non-activating, transparent `NSPanel` at `.statusBar` level that
    joins all Spaces and full-screen apps, so it never steals keyboard focus.
  - Positioned in the corner chosen in Settings (`entrySide` left/right × `verticalPosition`
    bottom/top) of the screen under the mouse. Coming from the right mirrors the frames and flips the bubble. The walk is the *window* moving
    (`NSAnimationContext`), while the sprite plays the walk cycle.
  - Sequence: walk in 2.6 s → sip 2.2 s → ask → (answer) → 1.8 s cheer/ack → walk out 2 s.
    Auto-snoozes after `autoSnoozeMinutes` with no answer.
  - Every pending step is a cancellable `DispatchWorkItem`.
- **`ReminderView` / `CharacterView`**: the SwiftUI overlay content. `SpriteSet` loads
  `idle_* / walk_* / sip_* / cheer_*` PNGs from the Character folder (sorted by frame number) with
  per-pose fallbacks; `SpriteView` plays them via `TimelineView` (idle uses blink timing).
  With no frames, `DrawnCharacter` draws the built-in chibi in SwiftUI shapes.
- **`AudioPlayer`**: looping music from the user's files (fades in and out), plus one-shot
  effects (`appear`, `cheer`). Missing or broken files are silently skipped.
- **`SpotlightActions`**: keeps tiny launcher apps in `~/Applications/Sippy Actions/`, named
  *Log Water – …* to match the tracking mode. Each one is just an `Info.plist` and a shell script that
  runs `open -g "sippy://log?amount=…"`. Sippy rebuilds them at launch and when the mode changes,
  registers them with Launch Services, and runs `mdimport` so Spotlight finds them right away.
  (Real App Shortcuts would need Xcode's App Intents metadata step, which the Command Line Tools
  don't have.)
- **`sippy://` links**: the `sippy` URL scheme is declared in `Info.plist`. `AppModel.handle(url:)` resolves
  `amount` (glass / sips / quarter / half / bottle / millilitres) via `Amounts.ml(forAmount:)`. A log from a
  link, Spotlight or the menu counts as the answer if the character is asking. Otherwise it logs,
  restarts the reminder countdown, and shows a `Toast` under the menu bar.
- **`DashboardView`**: Swift Charts bar chart with a goal rule, stat tiles, history list, and logging.
- **`SettingsView`**: a grouped `Form`. Every control writes through `AppModel.update`, which
  clamps, saves, and reschedules if the interval changed. *Open at login* uses `SMAppService.mainApp`.

## Files on disk

| Path | What |
|---|---|
| `/Applications/Sippy.app` | The app |
| `~/Library/Application Support/Sippy/intake.json` | Drink log: `[{"date": …, "ml": 250}, …]` |
| `~/Library/Application Support/Sippy/Character/` | Custom frames and sounds |
| `defaults read com.vipulchaudhary.sippy` | Settings (`sippy.settings.v1`) and the first-launch flag |

To reset everything: quit Sippy, delete the `Sippy` folder above, and run
`defaults delete com.vipulchaudhary.sippy`.

## Build pipeline (no Xcode)

`native/scripts/build.sh` uses only the Command Line Tools:

1. `swift run -c release SippyChecks`: the build stops if a check fails.
2. `swift build -c release --product Sippy`.
3. Assembles `dist/Sippy.app`: binary, generated `Info.plist` (`LSUIElement` = menu-bar app,
   bundle ID `com.vipulchaudhary.sippy`), and `Sippy.icns`.
4. The icon is drawn by `scripts/make_icon.swift` (AppKit drawing → `.iconset` → `iconutil`).
5. `codesign --sign -` (ad-hoc), then `hdiutil` makes `dist/Sippy.dmg` with an Applications link.
6. `--install` replaces `/Applications/Sippy.app` and launches it.

Builds also produce `dist/Sippy.zip`. Set `VERSION=x.y.z` to stamp the version, and
`UNIVERSAL=1` for an arm64 + x86_64 binary (needs full Xcode).

**Releases:** `.github/workflows/release.yml` runs on any `v*` tag on a `macos-15` runner. It runs
`UNIVERSAL=1 scripts/build.sh` (checks included), names the files `Sippy-<version>.dmg/.zip`, writes
`SHA256SUMS.txt`, and publishes a GitHub release with install instructions and auto-generated notes.

For a version that opens without the right-click → Open step on other Macs, sign with a
Developer ID certificate and notarize (`xcrun notarytool`). That needs an Apple Developer account.

## Checks

XCTest and Swift Testing aren't loadable with Command Line Tools alone, so `SippyChecks` is a
small executable with a `check(...)` helper:

```sh
cd native && swift run SippyChecks
```

It covers settings clamping, persistence and backward-compatible decoding, intake-log persistence,
undo and migration, daily totals, streaks, the last-N-days window, glass/bottle unit formatting
and answer options, and scheduler timing (fires once when due, waits while held).

UI is checked visually with the preview renderer, which draws each overlay stage offscreen:

```sh
.build/debug/Sippy --render-previews /tmp/previews            # with your Character folder
.build/debug/Sippy --render-previews /tmp/previews --builtin  # built-in character
```

## History

The first version was a Flutter desktop prototype; its design spec and plan are in
`docs/superpowers/`. Flutter's macOS builds need full Xcode, so the app was rewritten natively and
the Flutter code was removed. It's still in the git history from before the rewrite.
