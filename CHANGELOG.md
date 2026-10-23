# Changelog

All notable changes to Sippy. Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versions follow [Semantic Versioning](https://semver.org/).

Each release's notes on GitHub are taken from its section here, so add one before tagging.

## [Unreleased]

### Added
- **Calendar knocks.** A few minutes before each event, the character walks in, knocks on your
  screen with a knock sound, and tells you what's starting, with a **Join meeting** button for
  Zoom, Google Meet, Teams, Webex and FaceTime links. Reads macOS Calendar, so Google, iCloud,
  Outlook and Exchange calendars added in Internet Accounts work. Choose the lead time and which
  calendars to watch; all-day and declined events are skipped. Off by default.
- The menu shows your next event.
- Custom characters can add `knock_0.png` / `knock_1.png` and `knock.mp3` (prompts in the
  character guide).
- *Test knock* uses your real next meeting.
- Dashboard **Up next** card: today's remaining meetings with **Join** buttons.

### Changed
- **Settings has tabs:** Water, Meetings, Character, General.
- **The menu has Water and Meetings sections.** Today's meetings are listed, and clicking one
  with a video link joins it.
- Far-off times read as hours, e.g. *starts in 2 h 30 min*.

## [1.2.0] - 2026-10-23

### Added
- **Reminder hours.** Only remind between set times (e.g. 11:00–19:00), in Settings → Reminder hours.
  Reminders that would land outside wait for the window to open; overnight ranges like 22:00–06:00
  work too. Off by default. *Remind Me Now* always works.
- **Log water from Spotlight.** Press ⌘Space, type **log water** and press Enter. Pick *Glass*, or
  *A Few Sips / ¼ / ½ / Whole Bottle* in bottle mode. Works in Raycast and Alfred too. Turn it off in
  Settings → General.
- **`sippy://` links** for Shortcuts, Raycast, Alfred, Stream Deck or Terminal:
  `sippy://log?amount=glass|sips|quarter|half|bottle|<ml>`.
- **Cheer in the middle of the screen.** Logging from Spotlight, a link or the menu makes the
  character pop up at screen centre, dance, and play your cheer sound.
- The menu shows the clock time for far-off reminders, e.g. *Next reminder at 11:00 AM tomorrow*.

### Changed
- Logging a drink from anywhere restarts the reminder countdown, and counts as your answer if the
  character is on screen asking.

## [1.1.0] - 2026-10-22

### Added
- **Choose the corner** the character comes from: left or right, along the bottom or the top
  (Settings → Character). Coming from the right mirrors the frames so the character faces into the
  screen, and the speech bubble flips.

### Fixed
- Litres show two decimals, so today plus remaining adds up to the goal (0.25 + 2.25 L used to show
  as 0.3 + 2.3).
- The 7-day average no longer shows 0.0 for small amounts.
- Settings wording is neutral for the built-in character.

## [1.0.0] - 2026-10-22

First release of the native macOS app.

### Added
- Menu-bar app (no Dock icon) that runs in the background and can open at login.
- A character walks onto your screen, sips, and asks whether you drank: **Yes** or **Snooze**.
  Auto-snoozes if you're away.
- **Glasses or bottle** tracking: daily goal in glasses, or in litres with *a few sips / ¼ / ½ /
  whole bottle* answers.
- Dashboard: today's progress, streak, 7-day chart, 30-day history.
- Settings: interval, snooze, goal, music, volume and mute.
- **Custom character:** drop in your own PNG frames (idle, walk, sip, cheer), plus `appear.mp3` and
  `cheer.mp3` sounds. Includes an AI prompt guide and a frame checker script.
- Reminders wait while the screen is locked or asleep, then give you a minute after you return.
- Universal build (Apple silicon + Intel), macOS 13+.

[1.2.0]: https://github.com/vipulchaudhary16/Sippy/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/vipulchaudhary16/Sippy/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/vipulchaudhary16/Sippy/releases/tag/v1.0.0
