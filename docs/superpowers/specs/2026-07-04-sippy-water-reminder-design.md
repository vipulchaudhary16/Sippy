# Sippy — Desktop Water-Reminder Character (Design)

**Date:** 2026-07-04
**Status:** Approved for planning
**Stack:** Flutter desktop (macOS, Windows, Linux)

## Summary

A cross-platform desktop app. On a user-configured interval, an animated
character walks in from the left edge of the screen, takes a sip of water,
and shows a speech bubble reminding the user to drink water, with **YES,
DRANK** and **SNOOZE** buttons. Background music plays while the character is
on screen. The app tracks water intake over time and shows history and stats.

The visual reference: a pixel-art character standing on the desktop (floating
over other apps, transparent background — a "desktop pet" overlay), speech
bubble above, two buttons below.

## Goals

- Animated character (sprite frames: idle, walk-in, sip) on a transparent,
  always-on-top desktop overlay.
- Fully configurable reminder interval and snooze duration.
- Track every logged glass; show full history + weekly-trend stats.
- Background music that the user supplies, with volume + mute.
- Cross-platform: macOS, Windows, Linux from a single Flutter codebase.

## Non-Goals (YAGNI)

- No active-hours / do-not-disturb window in v1 (interval only).
- No cloud sync or accounts — all data is local.
- No pre-rendered transparent video (we use sprite frames instead).

## Decisions (from brainstorming)

| Question | Decision |
|---|---|
| Platforms | Cross-platform (macOS + Windows + Linux) |
| Animation | Sprite / frame animation (idle, walk, sip) |
| Reminder timing | Custom user-configured interval |
| Snooze | Configurable snooze duration |
| "YES, DRANK" behavior | Full tracking: history + stats/charts |
| Music | User-supplied files, volume control, mute toggle |
| Tech stack | Flutter desktop (`window_manager` for the overlay) |

## Architecture — three surfaces, one app

- **Overlay stage** — a transparent, borderless, always-on-top window. Hosts
  the character sprite, speech bubble, and the YES/SNOOZE buttons. Plays music
  while visible. Dismisses after the user responds.
- **Dashboard window** — a normal window: today's progress (e.g. 6/8 glasses),
  weekly-trend chart, streak, full history.
- **Settings window** — interval, snooze duration, daily goal, music files,
  volume/mute, character entry position.
- **Menu-bar / tray icon** — opens dashboard, opens settings, "remind me now",
  quit.

## Components

| Component | Responsibility |
|---|---|
| `ReminderScheduler` | Fires reminders on the custom interval; handles snooze re-fires |
| `OverlayController` | Creates/positions the transparent window; runs entry -> sip -> prompt sequence |
| `SpriteAnimator` | Plays frame sets: idle, walk, sip (transparent PNG frames) |
| `AudioManager` | Loads user music, loops it, volume + mute |
| `WaterRepository` | SQLite (drift): log entries, daily goal, streak calc, history queries |
| `StatsViewModel` | Feeds dashboard charts (fl_chart) |
| `SettingsStore` | Persists all preferences |

## Data flow

1. `ReminderScheduler` timer fires.
2. `OverlayController` shows the stage; `SpriteAnimator` plays walk-in + sip;
   `AudioManager` starts music.
3. User responds:
   - **YES, DRANK** -> `WaterRepository` logs an entry (timestamp) -> music
     stops, character exits -> timer resets.
   - **SNOOZE** -> scheduler re-fires after the configured snooze duration ->
     character exits.

## Data model (SQLite via drift)

- `intake_log(id, timestamp)` — one row per glass logged.
- `settings(key, value)` — interval, snooze duration, daily goal, volume,
  mute, music file paths, character position.
- Streaks and weekly trends are **computed** from `intake_log`, not stored.

## Assets

AI-generated character as transparent PNG **sprite frames**: an idle pose, a
short walk cycle (~4-6 frames), and a sip pose. Generated once and bundled.
Rough placeholder frames used first so art does not block development.

## Error handling

- Transparent overlay window fails to create on a platform -> fall back to a
  native OS notification so the reminder still fires.
- Missing/deleted music file -> skip audio silently, no crash.
- Empty history -> dashboard shows a friendly "no data yet" state.

## Testing

- Unit tests: scheduler timing/snooze logic, streak & daily-total
  calculations, settings persistence.
- Manual/POC: transparent overlay window on macOS first (highest risk),
  verified before building features on top.

## Build order (de-risk first)

1. **Overlay POC** — transparent always-on-top window + sliding sprite on macOS.
2. Scheduler + the OK/Snooze flow.
3. Data layer + logging.
4. Dashboard charts.
5. Settings + audio.
6. Cross-platform pass (Windows/Linux).

## Key libraries

- `window_manager` — transparent, borderless, always-on-top overlay.
- `screen_retriever` — screen bounds for positioning the walk-in.
- `flame` or plain sprite sheets — frame animation.
- `audioplayers` — background music, volume, mute.
- `drift` — SQLite data layer.
- `fl_chart` — dashboard charts.
- `local_notifier` / `tray_manager` — notification fallback + tray icon.
