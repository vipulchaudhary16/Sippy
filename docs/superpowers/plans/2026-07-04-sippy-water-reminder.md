# Sippy Water-Reminder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A cross-platform Flutter desktop app where an animated character walks in on a timer, reminds the user to drink water with YES/SNOOZE buttons and background music, and tracks intake with history and stats.

**Architecture:** A single Flutter desktop app with three surfaces — a transparent always-on-top *overlay stage* (the character), a *dashboard* window (stats/history), and a *settings* window — tied together by a tray/menu-bar icon. Pure logic (scheduler, repository, stats, settings) is built test-first; platform/UI pieces (overlay window, sprites, audio, charts) are built with real code and verified manually. The transparent overlay is built first to de-risk it.

**Tech Stack:** Flutter (desktop), Dart 3, `window_manager`, `screen_retriever`, `drift` (SQLite), `shared_preferences`, `audioplayers`, `fl_chart`, `tray_manager`, `local_notifier`.

## Global Constraints

- Target platforms: macOS, Windows, Linux (verify macOS first).
- Flutter stable channel, Dart SDK `>=3.4.0`.
- All data local — no network, no accounts.
- Reminder interval and snooze duration are both user-configurable (no hardcoded values).
- Every audio surface has a mute toggle and volume control.
- Streaks and weekly trends are **computed** from `intake_log`, never stored.
- Working directory: `/Users/vipulchaudhary/Personal/sippy`.

---

### Task 1: Scaffold the Flutter desktop project

**Files:**
- Create: whole `flutter create` skeleton in `/Users/vipulchaudhary/Personal/sippy`
- Modify: `pubspec.yaml`
- Test: `test/smoke_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: a buildable Flutter desktop project with all dependencies resolved; `flutter test` runs green.

- [ ] **Step 1: Create the Flutter app in place**

```bash
cd /Users/vipulchaudhary/Personal/sippy
flutter create --platforms=macos,windows,linux --org com.sippy --project-name sippy .
```

- [ ] **Step 2: Add dependencies**

Edit `pubspec.yaml` `dependencies:` and `dev_dependencies:` to include:

```yaml
environment:
  sdk: '>=3.4.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  window_manager: ^0.4.0
  screen_retriever: ^0.2.0
  drift: ^2.18.0
  sqlite3_flutter_libs: ^0.5.0
  path_provider: ^2.1.0
  path: ^1.9.0
  shared_preferences: ^2.3.0
  audioplayers: ^6.0.0
  fl_chart: ^0.68.0
  tray_manager: ^0.2.3
  local_notifier: ^0.1.6
  file_picker: ^8.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  drift_dev: ^2.18.0
  build_runner: ^2.4.0
```

- [ ] **Step 3: Resolve dependencies**

Run: `flutter pub get`
Expected: "Got dependencies!" with no version-solve errors.

- [ ] **Step 4: Write a smoke test**

Create `test/smoke_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('project builds and tests run', () {
    expect(1 + 1, equals(2));
  });
}
```

- [ ] **Step 5: Run the smoke test**

Run: `flutter test test/smoke_test.dart`
Expected: PASS (1 test passed).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore: scaffold Flutter desktop project with dependencies"
```

---

### Task 2: Overlay POC — transparent always-on-top window with a sliding box

This is the highest-risk piece. Prove the transparent, borderless, always-on-top window works on macOS and that a widget can slide in from the left, **before** building real features on it.

**Files:**
- Create: `lib/overlay/overlay_window.dart`
- Modify: `lib/main.dart`
- Modify (macOS transparency): `macos/Runner/MainFlutterWindow.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `configureOverlayWindow()` — async, sets the main window transparent/borderless/always-on-top/full-screen-sized and shows it; `SlidingBox` widget that animates a colored box from x=0 to a target x.

- [ ] **Step 1: Configure the native macOS window for transparency**

In `macos/Runner/MainFlutterWindow.swift`, inside `awakeFromNib()` after `self.setFrame(...)` and before `super.awakeFromNib()`, add:

```swift
self.isOpaque = false
self.backgroundColor = .clear
self.titlebarAppearsTransparent = true
self.titleVisibility = .hidden
self.styleMask.insert(.fullSizeContentView)
self.isMovableByWindowBackground = false
```

- [ ] **Step 2: Write the overlay window configuration**

Create `lib/overlay/overlay_window.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

/// Makes the app's main window a transparent, borderless, always-on-top
/// overlay that covers the primary display so the character can be drawn
/// anywhere on screen with a see-through background.
Future<void> configureOverlayWindow() async {
  await windowManager.ensureInitialized();

  final display = await screenRetriever.getPrimaryDisplay();
  final size = display.size;

  const options = WindowOptions(
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.hidden,
    skipTaskbar: true,
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setAsFrameless();
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setHasShadow(false);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setIgnoreMouseEvents(false);
    await windowManager.setSize(size);
    await windowManager.setPosition(const Offset(0, 0));
    await windowManager.show();
  });
}
```

- [ ] **Step 3: Write a SlidingBox POC widget and wire up main.dart**

Replace `lib/main.dart` with:

```dart
import 'package:flutter/material.dart';
import 'overlay/overlay_window.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureOverlayWindow();
  runApp(const PocApp());
}

class PocApp extends StatelessWidget {
  const PocApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: SlidingBox(),
      ),
    );
  }
}

class SlidingBox extends StatefulWidget {
  const SlidingBox({super.key});

  @override
  State<SlidingBox> createState() => _SlidingBoxState();
}

class _SlidingBoxState extends State<SlidingBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final x = _controller.value * (width * 0.5);
        return Stack(children: [
          Positioned(
            left: x,
            bottom: 80,
            child: Container(width: 120, height: 220, color: Colors.teal),
          ),
        ]);
      },
    );
  }
}
```

- [ ] **Step 4: Run on macOS and verify manually**

Run: `flutter run -d macos`
Expected: A teal box slides in from the left edge over your desktop/other apps, with a fully transparent background (you can see your desktop around it), and the window stays on top. Note any failure — this gates the whole approach.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: transparent always-on-top overlay window POC with sliding box"
```

---

### Task 3: AppSettings model + SettingsStore (TDD)

**Files:**
- Create: `lib/settings/app_settings.dart`
- Create: `lib/settings/settings_store.dart`
- Test: `test/settings_store_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `AppSettings` — immutable class with `Duration intervalMinutes` (stored as `int intervalMinutes`), `int snoozeMinutes`, `int dailyGoal`, `double volume` (0.0–1.0), `bool muted`, `List<String> musicPaths`; a `const AppSettings.defaults()` and `copyWith(...)`.
  - `SettingsStore` — `Future<AppSettings> load()`, `Future<void> save(AppSettings)`, backed by `SharedPreferences`. Constructor takes `SharedPreferences prefs` for testability.

- [ ] **Step 1: Write the failing test**

Create `test/settings_store_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sippy/settings/app_settings.dart';
import 'package:sippy/settings/settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('load returns defaults when nothing saved', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SettingsStore(prefs);

    final settings = await store.load();

    expect(settings, equals(const AppSettings.defaults()));
  });

  test('save then load round-trips all fields', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SettingsStore(prefs);

    const custom = AppSettings(
      intervalMinutes: 45,
      snoozeMinutes: 15,
      dailyGoal: 10,
      volume: 0.3,
      muted: true,
      musicPaths: ['/music/a.mp3', '/music/b.mp3'],
    );
    await store.save(custom);

    expect(await store.load(), equals(custom));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/settings_store_test.dart`
Expected: FAIL — `AppSettings` / `SettingsStore` not defined.

- [ ] **Step 3: Write AppSettings**

Create `lib/settings/app_settings.dart`:

```dart
import 'package:flutter/foundation.dart';

@immutable
class AppSettings {
  final int intervalMinutes;
  final int snoozeMinutes;
  final int dailyGoal;
  final double volume;
  final bool muted;
  final List<String> musicPaths;

  const AppSettings({
    required this.intervalMinutes,
    required this.snoozeMinutes,
    required this.dailyGoal,
    required this.volume,
    required this.muted,
    required this.musicPaths,
  });

  const AppSettings.defaults()
      : intervalMinutes = 60,
        snoozeMinutes = 10,
        dailyGoal = 8,
        volume = 0.5,
        muted = false,
        musicPaths = const [];

  AppSettings copyWith({
    int? intervalMinutes,
    int? snoozeMinutes,
    int? dailyGoal,
    double? volume,
    bool? muted,
    List<String>? musicPaths,
  }) {
    return AppSettings(
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      volume: volume ?? this.volume,
      muted: muted ?? this.muted,
      musicPaths: musicPaths ?? this.musicPaths,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.intervalMinutes == intervalMinutes &&
      other.snoozeMinutes == snoozeMinutes &&
      other.dailyGoal == dailyGoal &&
      other.volume == volume &&
      other.muted == muted &&
      listEquals(other.musicPaths, musicPaths);

  @override
  int get hashCode => Object.hash(intervalMinutes, snoozeMinutes, dailyGoal,
      volume, muted, Object.hashAll(musicPaths));
}
```

- [ ] **Step 4: Write SettingsStore**

Create `lib/settings/settings_store.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'app_settings.dart';

class SettingsStore {
  final SharedPreferences _prefs;
  SettingsStore(this._prefs);

  static const _kInterval = 'intervalMinutes';
  static const _kSnooze = 'snoozeMinutes';
  static const _kGoal = 'dailyGoal';
  static const _kVolume = 'volume';
  static const _kMuted = 'muted';
  static const _kMusic = 'musicPaths';

  Future<AppSettings> load() async {
    const d = AppSettings.defaults();
    return AppSettings(
      intervalMinutes: _prefs.getInt(_kInterval) ?? d.intervalMinutes,
      snoozeMinutes: _prefs.getInt(_kSnooze) ?? d.snoozeMinutes,
      dailyGoal: _prefs.getInt(_kGoal) ?? d.dailyGoal,
      volume: _prefs.getDouble(_kVolume) ?? d.volume,
      muted: _prefs.getBool(_kMuted) ?? d.muted,
      musicPaths: _prefs.getStringList(_kMusic) ?? d.musicPaths,
    );
  }

  Future<void> save(AppSettings s) async {
    await _prefs.setInt(_kInterval, s.intervalMinutes);
    await _prefs.setInt(_kSnooze, s.snoozeMinutes);
    await _prefs.setInt(_kGoal, s.dailyGoal);
    await _prefs.setDouble(_kVolume, s.volume);
    await _prefs.setBool(_kMuted, s.muted);
    await _prefs.setStringList(_kMusic, s.musicPaths);
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/settings_store_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: AppSettings model and SettingsStore with persistence"
```

---

### Task 4: Data layer — drift database + WaterRepository (TDD)

**Files:**
- Create: `lib/data/database.dart`
- Create: `lib/data/water_repository.dart`
- Test: `test/water_repository_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `AppDatabase` — drift DB with an `IntakeLog` table (`id` autoincrement, `timestamp` DateTime). Has a named `AppDatabase.forTesting(QueryExecutor)` constructor.
  - `WaterRepository(AppDatabase db)` with:
    - `Future<int> logGlass(DateTime at)` → inserts a row, returns row id.
    - `Future<int> countForDay(DateTime day)` → number of glasses logged on that calendar day.
    - `Future<List<DateTime>> allTimestamps()` → every logged timestamp ascending.

- [ ] **Step 1: Define the drift table and database**

Create `lib/data/database.dart`:

```dart
import 'package:drift/drift.dart';

part 'database.g.dart';

class IntakeLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get timestamp => dateTime()();
}

@DriftDatabase(tables: [IntakeLog])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}
```

- [ ] **Step 2: Generate drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `database.g.dart` created, build succeeds.

- [ ] **Step 3: Write the failing test**

Create `test/water_repository_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sippy/data/database.dart';
import 'package:sippy/data/water_repository.dart';

void main() {
  late AppDatabase db;
  late WaterRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = WaterRepository(db);
  });

  tearDown(() async => db.close());

  test('logGlass inserts and countForDay counts same-day rows', () async {
    final day = DateTime(2026, 7, 4, 9);
    await repo.logGlass(DateTime(2026, 7, 4, 9, 0));
    await repo.logGlass(DateTime(2026, 7, 4, 14, 0));
    await repo.logGlass(DateTime(2026, 7, 5, 10, 0)); // next day

    expect(await repo.countForDay(day), equals(2));
  });

  test('allTimestamps returns everything ascending', () async {
    await repo.logGlass(DateTime(2026, 7, 4, 14));
    await repo.logGlass(DateTime(2026, 7, 4, 9));

    final all = await repo.allTimestamps();
    expect(all.first.isBefore(all.last), isTrue);
    expect(all.length, equals(2));
  });
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/water_repository_test.dart`
Expected: FAIL — `WaterRepository` not defined.

- [ ] **Step 5: Write WaterRepository**

Create `lib/data/water_repository.dart`:

```dart
import 'package:drift/drift.dart';
import 'database.dart';

class WaterRepository {
  final AppDatabase _db;
  WaterRepository(this._db);

  Future<int> logGlass(DateTime at) {
    return _db.into(_db.intakeLog).insert(
          IntakeLogCompanion.insert(timestamp: at),
        );
  }

  Future<int> countForDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final query = _db.select(_db.intakeLog)
      ..where((t) =>
          t.timestamp.isBiggerOrEqualValue(start) &
          t.timestamp.isSmallerThanValue(end));
    final rows = await query.get();
    return rows.length;
  }

  Future<List<DateTime>> allTimestamps() async {
    final query = _db.select(_db.intakeLog)
      ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]);
    final rows = await query.get();
    return rows.map((r) => r.timestamp).toList();
  }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/water_repository_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: drift database and WaterRepository for intake logging"
```

---

### Task 5: Stats computation — daily totals, streak, weekly trend (TDD)

**Files:**
- Create: `lib/dashboard/water_stats.dart`
- Test: `test/water_stats_test.dart`

**Interfaces:**
- Consumes: `List<DateTime>` (from `WaterRepository.allTimestamps`) and `int dailyGoal`.
- Produces: `WaterStats` — pure static functions:
  - `static Map<DateTime, int> countsByDay(List<DateTime> stamps)` — key is date at midnight.
  - `static int currentStreak(List<DateTime> stamps, int dailyGoal, DateTime today)` — consecutive days up to and including `today` where count ≥ goal.
  - `static List<int> lastSevenDays(List<DateTime> stamps, DateTime today)` — counts for the 7 days ending at `today`, oldest first.

- [ ] **Step 1: Write the failing test**

Create `test/water_stats_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sippy/dashboard/water_stats.dart';

void main() {
  test('countsByDay groups by calendar day', () {
    final counts = WaterStats.countsByDay([
      DateTime(2026, 7, 4, 9),
      DateTime(2026, 7, 4, 18),
      DateTime(2026, 7, 5, 8),
    ]);
    expect(counts[DateTime(2026, 7, 4)], equals(2));
    expect(counts[DateTime(2026, 7, 5)], equals(1));
  });

  test('currentStreak counts consecutive goal-met days ending today', () {
    final today = DateTime(2026, 7, 4);
    final stamps = <DateTime>[
      ...List.generate(2, (_) => DateTime(2026, 7, 2, 9)), // goal=2 met
      ...List.generate(2, (_) => DateTime(2026, 7, 3, 9)),
      ...List.generate(2, (_) => DateTime(2026, 7, 4, 9)),
    ];
    expect(WaterStats.currentStreak(stamps, 2, today), equals(3));
  });

  test('currentStreak breaks when a day misses goal', () {
    final today = DateTime(2026, 7, 4);
    final stamps = <DateTime>[
      DateTime(2026, 7, 3, 9), // only 1, goal 2 -> miss
      DateTime(2026, 7, 4, 9),
      DateTime(2026, 7, 4, 10),
    ];
    expect(WaterStats.currentStreak(stamps, 2, today), equals(1));
  });

  test('lastSevenDays returns 7 counts oldest first', () {
    final today = DateTime(2026, 7, 4);
    final counts = WaterStats.lastSevenDays(
        [DateTime(2026, 7, 4, 9), DateTime(2026, 6, 28, 9)], today);
    expect(counts.length, equals(7));
    expect(counts.first, equals(1)); // 2026-06-28 is 7th-from-today
    expect(counts.last, equals(1)); // today
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/water_stats_test.dart`
Expected: FAIL — `WaterStats` not defined.

- [ ] **Step 3: Write WaterStats**

Create `lib/dashboard/water_stats.dart`:

```dart
class WaterStats {
  static DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

  static Map<DateTime, int> countsByDay(List<DateTime> stamps) {
    final map = <DateTime, int>{};
    for (final s in stamps) {
      final key = _midnight(s);
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  static int currentStreak(
      List<DateTime> stamps, int dailyGoal, DateTime today) {
    final counts = countsByDay(stamps);
    var streak = 0;
    var day = _midnight(today);
    while ((counts[day] ?? 0) >= dailyGoal) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static List<int> lastSevenDays(List<DateTime> stamps, DateTime today) {
    final counts = countsByDay(stamps);
    final result = <int>[];
    for (var i = 6; i >= 0; i--) {
      final day = _midnight(today).subtract(Duration(days: i));
      result.add(counts[day] ?? 0);
    }
    return result;
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/water_stats_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: WaterStats for daily totals, streaks, and weekly trend"
```

---

### Task 6: ReminderScheduler (TDD with injectable timer)

**Files:**
- Create: `lib/scheduler/reminder_scheduler.dart`
- Test: `test/reminder_scheduler_test.dart`

**Interfaces:**
- Consumes: `AppSettings` (for `intervalMinutes` / `snoozeMinutes`).
- Produces: `ReminderScheduler`:
  - Constructor `ReminderScheduler({required void Function() onFire})`.
  - `void start(Duration interval)` — schedules `onFire` after `interval`, repeating on each `start`/`reset`.
  - `void snooze(Duration snoozeFor)` — cancels the pending timer and schedules `onFire` after `snoozeFor`.
  - `void reset(Duration interval)` — cancels and reschedules with `interval`.
  - `void stop()` — cancels any pending timer.
  - Uses `Timer` internally but exposes a `@visibleForTesting` seam via a `Timer Function(Duration, void Function())` factory param defaulting to `Timer.new`.

- [ ] **Step 1: Write the failing test**

Create `test/reminder_scheduler_test.dart`:

```dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sippy/scheduler/reminder_scheduler.dart';

void main() {
  test('fires onFire after the interval', () {
    fakeAsync((async) {
      var fired = 0;
      final s = ReminderScheduler(onFire: () => fired++);
      s.start(const Duration(minutes: 45));

      async.elapse(const Duration(minutes: 44));
      expect(fired, equals(0));
      async.elapse(const Duration(minutes: 1));
      expect(fired, equals(1));
    });
  });

  test('snooze reschedules onFire after snooze duration', () {
    fakeAsync((async) {
      var fired = 0;
      final s = ReminderScheduler(onFire: () => fired++);
      s.start(const Duration(minutes: 45));
      async.elapse(const Duration(minutes: 45));
      expect(fired, equals(1));

      s.snooze(const Duration(minutes: 10));
      async.elapse(const Duration(minutes: 9));
      expect(fired, equals(1));
      async.elapse(const Duration(minutes: 1));
      expect(fired, equals(2));
    });
  });

  test('stop cancels the pending timer', () {
    fakeAsync((async) {
      var fired = 0;
      final s = ReminderScheduler(onFire: () => fired++);
      s.start(const Duration(minutes: 45));
      s.stop();
      async.elapse(const Duration(hours: 1));
      expect(fired, equals(0));
    });
  });
}
```

Note: `fakeAsync` comes from the `fake_async` package (a transitive dep of `flutter_test`); if the import fails, add `fake_async: ^1.3.0` to `dev_dependencies` and `flutter pub get`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/reminder_scheduler_test.dart`
Expected: FAIL — `ReminderScheduler` not defined.

- [ ] **Step 3: Write ReminderScheduler**

Create `lib/scheduler/reminder_scheduler.dart`:

```dart
import 'dart:async';

class ReminderScheduler {
  final void Function() onFire;
  Timer? _timer;

  ReminderScheduler({required this.onFire});

  void start(Duration interval) => _schedule(interval);

  void reset(Duration interval) => _schedule(interval);

  void snooze(Duration snoozeFor) => _schedule(snoozeFor);

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _schedule(Duration d) {
    _timer?.cancel();
    _timer = Timer(d, onFire);
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/reminder_scheduler_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: ReminderScheduler with interval, snooze, and stop"
```

---

### Task 7: SpriteAnimator + character stage widget

Sprite frames animated by state (idle / walk / sip). Uses placeholder frames first — real AI-generated frames drop into the same asset paths later.

**Files:**
- Create: `lib/overlay/sprite_animator.dart`
- Create: `assets/character/` (placeholder PNGs: `idle_0.png`, `walk_0.png`..`walk_3.png`, `sip_0.png`, `sip_1.png`)
- Modify: `pubspec.yaml` (register assets)
- Test: `test/sprite_animator_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum CharacterState { idle, walking, sipping }`
  - `SpriteFrames` — `static const Map<CharacterState, List<String>>` mapping each state to its ordered asset paths.
  - `SpriteAnimator` widget: `SpriteAnimator({required CharacterState state, double fps = 8})` — cycles that state's frames at `fps`, shows the frame `Image.asset`.

- [ ] **Step 1: Create placeholder frame assets**

Create solid-color placeholder PNGs (any 120x220 PNG) at:
`assets/character/idle_0.png`, `walk_0.png`, `walk_1.png`, `walk_2.png`, `walk_3.png`, `sip_0.png`, `sip_1.png`.

```bash
mkdir -p assets/character
# Generate simple placeholders (requires ImageMagick; otherwise copy any PNG):
for f in idle_0 walk_0 walk_1 walk_2 walk_3 sip_0 sip_1; do \
  magick -size 120x220 xc:teal "assets/character/$f.png"; done
```

If ImageMagick is unavailable, copy any existing PNG into those 7 filenames.

- [ ] **Step 2: Register assets in pubspec.yaml**

Under `flutter:` add:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/character/
```

Run: `flutter pub get`

- [ ] **Step 3: Write the failing test**

Create `test/sprite_animator_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sippy/overlay/sprite_animator.dart';

void main() {
  test('every CharacterState has at least one frame', () {
    for (final state in CharacterState.values) {
      expect(SpriteFrames.frames[state], isNotNull);
      expect(SpriteFrames.frames[state]!.isNotEmpty, isTrue);
    }
  });

  test('walking has multiple frames for a cycle', () {
    expect(SpriteFrames.frames[CharacterState.walking]!.length,
        greaterThan(1));
  });
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/sprite_animator_test.dart`
Expected: FAIL — `SpriteFrames` not defined.

- [ ] **Step 5: Write SpriteAnimator**

Create `lib/overlay/sprite_animator.dart`:

```dart
import 'dart:async';
import 'package:flutter/material.dart';

enum CharacterState { idle, walking, sipping }

class SpriteFrames {
  static const Map<CharacterState, List<String>> frames = {
    CharacterState.idle: ['assets/character/idle_0.png'],
    CharacterState.walking: [
      'assets/character/walk_0.png',
      'assets/character/walk_1.png',
      'assets/character/walk_2.png',
      'assets/character/walk_3.png',
    ],
    CharacterState.sipping: [
      'assets/character/sip_0.png',
      'assets/character/sip_1.png',
    ],
  };
}

class SpriteAnimator extends StatefulWidget {
  final CharacterState state;
  final double fps;
  const SpriteAnimator({super.key, required this.state, this.fps = 8});

  @override
  State<SpriteAnimator> createState() => _SpriteAnimatorState();
}

class _SpriteAnimatorState extends State<SpriteAnimator> {
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _startCycle();
  }

  @override
  void didUpdateWidget(SpriteAnimator old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state || old.fps != widget.fps) {
      _index = 0;
      _startCycle();
    }
  }

  void _startCycle() {
    _timer?.cancel();
    final frames = SpriteFrames.frames[widget.state]!;
    if (frames.length <= 1) return;
    final period = Duration(milliseconds: (1000 / widget.fps).round());
    _timer = Timer.periodic(period, (_) {
      setState(() => _index = (_index + 1) % frames.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frames = SpriteFrames.frames[widget.state]!;
    return Image.asset(frames[_index % frames.length],
        width: 120, height: 220, gaplessPlayback: true);
  }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/sprite_animator_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: SpriteAnimator with idle/walk/sip frame cycling"
```

---

### Task 8: Character stage — walk-in sequence, speech bubble, YES/SNOOZE

Composes the sprite + a scripted sequence (walk in from left → sip → show bubble + buttons) into the overlay. Uses a callback contract so the app can wire logging/snooze.

**Files:**
- Create: `lib/overlay/character_stage.dart`
- Test: `test/character_stage_test.dart` (widget test)

**Interfaces:**
- Consumes: `SpriteAnimator`, `CharacterState`.
- Produces: `CharacterStage` widget: `CharacterStage({required String message, required VoidCallback onDrank, required VoidCallback onSnooze})`. Plays walk→sip→prompt, then renders the speech bubble with `message` and two buttons wired to the callbacks. Buttons have keys `Key('drank-button')` and `Key('snooze-button')`.

- [ ] **Step 1: Write the failing widget test**

Create `test/character_stage_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sippy/overlay/character_stage.dart';

void main() {
  testWidgets('shows message and fires callbacks', (tester) async {
    var drank = 0, snoozed = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CharacterStage(
          message: 'Have you drank water?',
          onDrank: () => drank++,
          onSnooze: () => snoozed++,
        ),
      ),
    ));

    // Let the walk/sip sequence complete.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.text('Have you drank water?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('drank-button')));
    await tester.tap(find.byKey(const Key('snooze-button')));
    expect(drank, equals(1));
    expect(snoozed, equals(1));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/character_stage_test.dart`
Expected: FAIL — `CharacterStage` not defined.

- [ ] **Step 3: Write CharacterStage**

Create `lib/overlay/character_stage.dart`:

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'sprite_animator.dart';

class CharacterStage extends StatefulWidget {
  final String message;
  final VoidCallback onDrank;
  final VoidCallback onSnooze;

  const CharacterStage({
    super.key,
    required this.message,
    required this.onDrank,
    required this.onSnooze,
  });

  @override
  State<CharacterStage> createState() => _CharacterStageState();
}

class _CharacterStageState extends State<CharacterStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _walk = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );
  CharacterState _state = CharacterState.walking;
  bool _showPrompt = false;

  @override
  void initState() {
    super.initState();
    _walk.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        setState(() => _state = CharacterState.sipping);
        Timer(const Duration(milliseconds: 1200), () {
          if (mounted) {
            setState(() {
              _state = CharacterState.idle;
              _showPrompt = true;
            });
          }
        });
      }
    });
    _walk.forward();
  }

  @override
  void dispose() {
    _walk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final targetX = width * 0.5 - 60;
    return AnimatedBuilder(
      animation: _walk,
      builder: (context, _) {
        final x = _walk.value * targetX;
        return Stack(children: [
          Positioned(
            left: x,
            bottom: 40,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_showPrompt) _bubble(),
                SpriteAnimator(state: _state),
                if (_showPrompt) _buttons(),
              ],
            ),
          ),
        ]);
      },
    );
  }

  Widget _bubble() => Container(
        constraints: const BoxConstraints(maxWidth: 240),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black87, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(widget.message,
            style: const TextStyle(color: Colors.black87)),
      );

  Widget _buttons() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            key: const Key('drank-button'),
            onPressed: widget.onDrank,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade400),
            child: const Text('YES, DRANK'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            key: const Key('snooze-button'),
            onPressed: widget.onSnooze,
            child: const Text('SNOOZE'),
          ),
        ],
      );
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/character_stage_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: CharacterStage with walk-in sequence, bubble, and buttons"
```

---

### Task 9: AudioManager (background music, volume, mute)

**Files:**
- Create: `lib/audio/audio_manager.dart`
- Test: `test/audio_manager_test.dart`

**Interfaces:**
- Consumes: `AppSettings` (volume, muted, musicPaths).
- Produces: `AudioManager` wrapping an `AudioPlayer` (injectable for tests):
  - `Future<void> play(List<String> paths, {required double volume, required bool muted})` — plays the first path (or a random one), loops it; if `muted` or `paths` empty, plays nothing.
  - `Future<void> stop()`.
  - `Future<void> setVolume(double v)`, `Future<void> setMuted(bool m)`.
  - Constructor `AudioManager({AudioPlayer? player})`.

Because `audioplayers` needs platform channels, the test verifies the *decision logic* (whether it attempts playback) via a thin injected fake, not real audio.

- [ ] **Step 1: Write the failing test**

Create `test/audio_manager_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sippy/audio/audio_manager.dart';

void main() {
  test('does not play when muted', () async {
    final fake = FakeAudioSink();
    final mgr = AudioManager.withSink(fake);
    await mgr.play(['/a.mp3'], volume: 0.5, muted: true);
    expect(fake.playing, isFalse);
  });

  test('does not play when no paths', () async {
    final fake = FakeAudioSink();
    final mgr = AudioManager.withSink(fake);
    await mgr.play([], volume: 0.5, muted: false);
    expect(fake.playing, isFalse);
  });

  test('plays first path at given volume', () async {
    final fake = FakeAudioSink();
    final mgr = AudioManager.withSink(fake);
    await mgr.play(['/a.mp3', '/b.mp3'], volume: 0.3, muted: false);
    expect(fake.playing, isTrue);
    expect(fake.lastPath, equals('/a.mp3'));
    expect(fake.volume, equals(0.3));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/audio_manager_test.dart`
Expected: FAIL — `AudioManager` / `FakeAudioSink` not defined.

- [ ] **Step 3: Write AudioManager with an injectable sink**

Create `lib/audio/audio_manager.dart`:

```dart
import 'package:audioplayers/audioplayers.dart';

/// Minimal audio interface so logic is testable without platform channels.
abstract class AudioSink {
  Future<void> loop(String path, double volume);
  Future<void> stop();
  Future<void> setVolume(double v);
}

class _RealSink implements AudioSink {
  final AudioPlayer _player;
  _RealSink(this._player);

  @override
  Future<void> loop(String path, double volume) async {
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(volume);
    await _player.play(DeviceFileSource(path));
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> setVolume(double v) => _player.setVolume(v);
}

class FakeAudioSink implements AudioSink {
  bool playing = false;
  String? lastPath;
  double volume = 0;

  @override
  Future<void> loop(String path, double v) async {
    playing = true;
    lastPath = path;
    volume = v;
  }

  @override
  Future<void> stop() async => playing = false;

  @override
  Future<void> setVolume(double v) async => volume = v;
}

class AudioManager {
  final AudioSink _sink;
  AudioManager({AudioPlayer? player})
      : _sink = _RealSink(player ?? AudioPlayer());
  AudioManager.withSink(this._sink);

  Future<void> play(List<String> paths,
      {required double volume, required bool muted}) async {
    if (muted || paths.isEmpty) return;
    await _sink.loop(paths.first, volume);
  }

  Future<void> stop() => _sink.stop();
  Future<void> setVolume(double v) => _sink.setVolume(v);
  Future<void> setMuted(bool m) => m ? _sink.setVolume(0) : Future.value();
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/audio_manager_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: AudioManager with looping music, volume, and mute"
```

---

### Task 10: App wiring — scheduler → overlay → log/snooze/music

Ties the pieces into a runnable reminder loop. The overlay is normally hidden and shown when the scheduler fires. This task's verification is manual (drive the real app), since it spans platform windows and audio.

**Files:**
- Create: `lib/app_controller.dart`
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `ReminderScheduler`, `OverlayController` (uses `configureOverlayWindow`/`windowManager` show/hide), `WaterRepository`, `AudioManager`, `SettingsStore`, `AppSettings`, `CharacterStage`.
- Produces: `AppController` — holds current `AppSettings`, starts the scheduler, and exposes `showReminder()` / `handleDrank()` / `handleSnooze()`. `main()` builds the object graph and shows the overlay hidden initially.

- [ ] **Step 1: Write AppController**

Create `lib/app_controller.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'audio/audio_manager.dart';
import 'data/water_repository.dart';
import 'scheduler/reminder_scheduler.dart';
import 'settings/app_settings.dart';
import 'settings/settings_store.dart';

class AppController extends ChangeNotifier {
  final WaterRepository repo;
  final AudioManager audio;
  final SettingsStore settingsStore;
  late final ReminderScheduler scheduler;

  AppSettings settings = const AppSettings.defaults();
  bool reminderVisible = false;

  AppController({
    required this.repo,
    required this.audio,
    required this.settingsStore,
  }) {
    scheduler = ReminderScheduler(onFire: showReminder);
  }

  Future<void> init() async {
    settings = await settingsStore.load();
    scheduler.start(Duration(minutes: settings.intervalMinutes));
  }

  Future<void> showReminder() async {
    reminderVisible = true;
    notifyListeners();
    await windowManager.show();
    await audio.play(settings.musicPaths,
        volume: settings.volume, muted: settings.muted);
  }

  Future<void> _dismiss() async {
    reminderVisible = false;
    notifyListeners();
    await audio.stop();
    await windowManager.hide();
  }

  Future<void> handleDrank() async {
    await repo.logGlass(DateTime.now());
    scheduler.reset(Duration(minutes: settings.intervalMinutes));
    await _dismiss();
  }

  Future<void> handleSnooze() async {
    scheduler.snooze(Duration(minutes: settings.snoozeMinutes));
    await _dismiss();
  }

  Future<void> applySettings(AppSettings s) async {
    settings = s;
    await settingsStore.save(s);
    scheduler.reset(Duration(minutes: s.intervalMinutes));
    notifyListeners();
  }
}
```

Note: `DateTime.now()` is fine in app code; it is only forbidden inside Workflow scripts.

- [ ] **Step 2: Wire main.dart to build the graph and render the overlay**

Replace `lib/main.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_controller.dart';
import 'audio/audio_manager.dart';
import 'data/database.dart';
import 'data/water_repository.dart';
import 'overlay/character_stage.dart';
import 'overlay/overlay_window.dart';
import 'settings/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureOverlayWindow();

  final dir = await getApplicationSupportDirectory();
  final db = AppDatabase(NativeDatabase(File(p.join(dir.path, 'sippy.sqlite'))));
  final prefs = await SharedPreferences.getInstance();

  final controller = AppController(
    repo: WaterRepository(db),
    audio: AudioManager(),
    settingsStore: SettingsStore(prefs),
  );
  await controller.init();

  runApp(SippyApp(controller: controller));
}

class SippyApp extends StatelessWidget {
  final AppController controller;
  const SippyApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            if (!controller.reminderVisible) return const SizedBox.shrink();
            return CharacterStage(
              message: 'Have you drank water?',
              onDrank: controller.handleDrank,
              onSnooze: controller.handleSnooze,
            );
          },
        ),
      ),
    );
  }
}
```

Add `import 'dart:io';` at the top of `main.dart` for `File`.

- [ ] **Step 3: Manually verify the full loop**

Temporarily set the default interval low for testing: in `lib/settings/app_settings.dart` `AppSettings.defaults()`, the value is `intervalMinutes = 60`; for this test only, run with a short interval by editing the DB/prefs OR temporarily change to `1` and revert after.

Run: `flutter run -d macos`
Expected: after the interval, the window shows, the character walks in from the left, sips, shows the bubble + buttons, and music (if configured) plays. Click **YES, DRANK** → window hides, a row is logged. Trigger again, click **SNOOZE** → window hides and reappears after the snooze duration.

- [ ] **Step 4: Revert the temporary interval and commit**

Revert `intervalMinutes` back to `60`.

```bash
git add -A
git commit -m "feat: wire scheduler, overlay, logging, snooze, and music into app loop"
```

---

### Task 11: Dashboard window (stats + history charts)

**Files:**
- Create: `lib/dashboard/dashboard_page.dart`
- Test: `test/dashboard_page_test.dart` (widget test with in-memory repo)

**Interfaces:**
- Consumes: `WaterRepository`, `WaterStats`, `AppSettings.dailyGoal`, `fl_chart`.
- Produces: `DashboardPage` widget: `DashboardPage({required WaterRepository repo, required int dailyGoal})`. Shows today's count vs goal, current streak, and a 7-day bar chart. Exposes a `Key('today-progress')` text and a `Key('streak-text')`.

- [ ] **Step 1: Write the failing widget test**

Create `test/dashboard_page_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sippy/data/database.dart';
import 'package:sippy/data/water_repository.dart';
import 'package:sippy/dashboard/dashboard_page.dart';

void main() {
  testWidgets('shows today count and streak', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = WaterRepository(db);
    await repo.logGlass(DateTime.now());
    await repo.logGlass(DateTime.now());

    await tester.pumpWidget(MaterialApp(
      home: DashboardPage(repo: repo, dailyGoal: 8),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('today-progress')), findsOneWidget);
    expect(find.textContaining('2'), findsWidgets);

    await db.close();
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/dashboard_page_test.dart`
Expected: FAIL — `DashboardPage` not defined.

- [ ] **Step 3: Write DashboardPage**

Create `lib/dashboard/dashboard_page.dart`:

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../data/water_repository.dart';
import 'water_stats.dart';

class DashboardPage extends StatefulWidget {
  final WaterRepository repo;
  final int dailyGoal;
  const DashboardPage({super.key, required this.repo, required this.dailyGoal});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<DateTime> _stamps = [];

  @override
  void initState() {
    super.initState();
    widget.repo.allTimestamps().then((s) {
      if (mounted) setState(() => _stamps = s);
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayCount =
        WaterStats.countsByDay(_stamps)[DateTime(today.year, today.month, today.day)] ?? 0;
    final streak = WaterStats.currentStreak(_stamps, widget.dailyGoal, today);
    final week = WaterStats.lastSevenDays(_stamps, today);

    return Scaffold(
      appBar: AppBar(title: const Text('Sippy — Progress')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Today: $todayCount / ${widget.dailyGoal} glasses',
              key: const Key('today-progress'),
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Current streak: $streak days',
              key: const Key('streak-text')),
          const SizedBox(height: 24),
          const Text('Last 7 days'),
          const SizedBox(height: 12),
          Expanded(child: _WeekChart(week)),
        ]),
      ),
    );
  }
}

class _WeekChart extends StatelessWidget {
  final List<int> counts;
  const _WeekChart(this.counts);

  @override
  Widget build(BuildContext context) {
    return BarChart(BarChartData(
      barGroups: [
        for (var i = 0; i < counts.length; i++)
          BarChartGroupData(x: i, barRods: [
            BarChartRodData(toY: counts[i].toDouble(), width: 16),
          ]),
      ],
      titlesData: const FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
    ));
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/dashboard_page_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: dashboard page with today progress, streak, and 7-day chart"
```

---

### Task 12: Settings window (interval, snooze, goal, music, volume/mute)

**Files:**
- Create: `lib/settings/settings_page.dart`
- Test: `test/settings_page_test.dart` (widget test)

**Interfaces:**
- Consumes: `AppSettings`, a `Future<void> Function(AppSettings)` save callback, `file_picker`.
- Produces: `SettingsPage` widget: `SettingsPage({required AppSettings initial, required Future<void> Function(AppSettings) onSave})`. Fields for interval (min), snooze (min), daily goal, volume slider, mute switch, and add/remove music files. Save button has `Key('save-settings')`.

- [ ] **Step 1: Write the failing widget test**

Create `test/settings_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sippy/settings/app_settings.dart';
import 'package:sippy/settings/settings_page.dart';

void main() {
  testWidgets('edits interval and saves', (tester) async {
    AppSettings? saved;
    await tester.pumpWidget(MaterialApp(
      home: SettingsPage(
        initial: const AppSettings.defaults(),
        onSave: (s) async => saved = s,
      ),
    ));

    await tester.enterText(find.byKey(const Key('interval-field')), '30');
    await tester.tap(find.byKey(const Key('save-settings')));
    await tester.pump();

    expect(saved, isNotNull);
    expect(saved!.intervalMinutes, equals(30));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/settings_page_test.dart`
Expected: FAIL — `SettingsPage` not defined.

- [ ] **Step 3: Write SettingsPage**

Create `lib/settings/settings_page.dart`:

```dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'app_settings.dart';

class SettingsPage extends StatefulWidget {
  final AppSettings initial;
  final Future<void> Function(AppSettings) onSave;
  const SettingsPage({super.key, required this.initial, required this.onSave});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final _interval =
      TextEditingController(text: widget.initial.intervalMinutes.toString());
  late final _snooze =
      TextEditingController(text: widget.initial.snoozeMinutes.toString());
  late final _goal =
      TextEditingController(text: widget.initial.dailyGoal.toString());
  late double _volume = widget.initial.volume;
  late bool _muted = widget.initial.muted;
  late List<String> _music = List.of(widget.initial.musicPaths);

  int _parse(TextEditingController c, int fallback) =>
      int.tryParse(c.text) ?? fallback;

  Future<void> _addMusic() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.audio, allowMultiple: true);
    if (result != null) {
      setState(() =>
          _music.addAll(result.files.map((f) => f.path).whereType<String>()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sippy — Settings')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        TextField(
          key: const Key('interval-field'),
          controller: _interval,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Interval (minutes)'),
        ),
        TextField(
          key: const Key('snooze-field'),
          controller: _snooze,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Snooze (minutes)'),
        ),
        TextField(
          key: const Key('goal-field'),
          controller: _goal,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Daily goal (glasses)'),
        ),
        const SizedBox(height: 16),
        Row(children: [
          const Text('Volume'),
          Expanded(
            child: Slider(
              value: _volume,
              onChanged: (v) => setState(() => _volume = v),
            ),
          ),
        ]),
        SwitchListTile(
          title: const Text('Mute'),
          value: _muted,
          onChanged: (v) => setState(() => _muted = v),
        ),
        const SizedBox(height: 8),
        Row(children: [
          const Text('Music'),
          const Spacer(),
          TextButton(onPressed: _addMusic, child: const Text('Add files')),
        ]),
        for (final path in _music)
          ListTile(
            dense: true,
            title: Text(path, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => setState(() => _music.remove(path)),
            ),
          ),
        const SizedBox(height: 24),
        ElevatedButton(
          key: const Key('save-settings'),
          onPressed: () => widget.onSave(AppSettings(
            intervalMinutes: _parse(_interval, widget.initial.intervalMinutes),
            snoozeMinutes: _parse(_snooze, widget.initial.snoozeMinutes),
            dailyGoal: _parse(_goal, widget.initial.dailyGoal),
            volume: _volume,
            muted: _muted,
            musicPaths: _music,
          )),
          child: const Text('Save'),
        ),
      ]),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/settings_page_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: settings page for interval, snooze, goal, music, volume, mute"
```

---

### Task 13: Tray icon + navigation + notification fallback

Adds the menu-bar/tray entry point to open the dashboard and settings, a "remind me now" action, and a native-notification fallback when the overlay cannot be shown.

**Files:**
- Create: `lib/tray/tray_service.dart`
- Modify: `lib/main.dart` (init tray, route to dashboard/settings windows)
- Modify: `lib/app_controller.dart` (add `showReminder` fallback to `local_notifier`)

**Interfaces:**
- Consumes: `tray_manager`, `local_notifier`, `AppController`.
- Produces: `TrayService` with `Future<void> init({required VoidCallback onDashboard, required VoidCallback onSettings, required VoidCallback onRemindNow, required VoidCallback onQuit})` that builds the tray menu and dispatches clicks.

- [ ] **Step 1: Write TrayService**

Create `lib/tray/tray_service.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';

class TrayService with TrayListener {
  final VoidCallback onDashboard;
  final VoidCallback onSettings;
  final VoidCallback onRemindNow;
  final VoidCallback onQuit;

  TrayService({
    required this.onDashboard,
    required this.onSettings,
    required this.onRemindNow,
    required this.onQuit,
  });

  Future<void> init() async {
    trayManager.addListener(this);
    await trayManager.setToolTip('Sippy');
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'dashboard', label: 'Open Dashboard'),
      MenuItem(key: 'settings', label: 'Settings'),
      MenuItem(key: 'remind', label: 'Remind me now'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Quit'),
    ]));
  }

  @override
  void onTrayIconMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'dashboard':
        onDashboard();
      case 'settings':
        onSettings();
      case 'remind':
        onRemindNow();
      case 'quit':
        onQuit();
    }
  }
}
```

- [ ] **Step 2: Add notification fallback to AppController.showReminder**

In `lib/app_controller.dart`, add import `import 'package:local_notifier/local_notifier.dart';` and wrap the window show in a try/catch:

```dart
  Future<void> showReminder() async {
    reminderVisible = true;
    notifyListeners();
    try {
      await windowManager.show();
      await audio.play(settings.musicPaths,
          volume: settings.volume, muted: settings.muted);
    } catch (_) {
      final n = LocalNotification(
        title: 'Sippy',
        body: 'Time to drink water!',
      );
      await n.show();
    }
  }
```

- [ ] **Step 3: Initialize tray and window routing in main.dart**

In `main()` (before `runApp`), after building `controller`, add:

```dart
  await localNotifier.setup(appName: 'Sippy');
  final tray = TrayService(
    onDashboard: () => controller.openDashboard(),
    onSettings: () => controller.openSettings(),
    onRemindNow: () => controller.showReminder(),
    onQuit: () => windowManager.destroy(),
  );
  await tray.init();
```

Add navigation to `AppController` via a `GlobalKey<NavigatorState>` or a routing flag. Simplest: add fields `bool showDashboard` / `bool showSettings` and methods `openDashboard()` / `openSettings()` that set the flag + `notifyListeners()` + `windowManager.show()`, and in `SippyApp.build` render `DashboardPage` / `SettingsPage` when those flags are set (checked before `reminderVisible`).

Concretely, add to `AppController`:

```dart
  bool showDashboard = false;
  bool showSettings = false;

  Future<void> openDashboard() async {
    showDashboard = true;
    showSettings = false;
    notifyListeners();
    await windowManager.show();
  }

  Future<void> openSettings() async {
    showSettings = true;
    showDashboard = false;
    notifyListeners();
    await windowManager.show();
  }
```

And in `SippyApp.build`, before the `reminderVisible` check:

```dart
            if (controller.showDashboard) {
              return DashboardPage(repo: controller.repo, dailyGoal: controller.settings.dailyGoal);
            }
            if (controller.showSettings) {
              return SettingsPage(
                initial: controller.settings,
                onSave: (s) async {
                  await controller.applySettings(s);
                  controller.showSettings = false;
                  controller.notifyListeners();
                  await windowManager.hide();
                },
              );
            }
```

Add the imports for `DashboardPage` and `SettingsPage` to `main.dart`.

- [ ] **Step 4: Manually verify tray flow**

Run: `flutter run -d macos`
Expected: a Sippy icon appears in the menu bar. "Open Dashboard" shows the stats window; "Settings" shows the settings form; "Remind me now" triggers the character immediately; "Quit" exits.

- [ ] **Step 5: Run the full test suite**

Run: `flutter test`
Expected: all tests PASS.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: tray menu, window routing, and notification fallback"
```

---

### Task 14: Cross-platform pass (Windows + Linux) and asset swap

Verify the overlay/tray/audio behave on Windows and Linux, and drop in the real AI-generated sprite frames.

**Files:**
- Modify (if needed): `windows/runner/*`, `linux/*` for transparency tweaks.
- Replace: `assets/character/*.png` with final AI-generated frames (same filenames).

- [ ] **Step 1: Swap in real sprite frames**

Replace the 7 placeholder PNGs in `assets/character/` with the AI-generated transparent frames, keeping the exact filenames (`idle_0.png`, `walk_0..3.png`, `sip_0..1.png`). If the walk cycle has a different frame count, update `SpriteFrames.frames[CharacterState.walking]` to match.

- [ ] **Step 2: Verify on Windows**

Run on a Windows machine: `flutter run -d windows`
Expected: transparent overlay + character + tray work. Note any transparency issues (Windows may need `window_manager` transparency flags already set in Task 2).

- [ ] **Step 3: Verify on Linux**

Run on a Linux machine with a compositor: `flutter run -d linux`
Expected: overlay shows; if transparency fails on the compositor, the notification fallback (Task 13) still delivers reminders. Document the result.

- [ ] **Step 4: Run full suite and commit**

Run: `flutter test`
Expected: all tests PASS.

```bash
git add -A
git commit -m "feat: cross-platform verification and final sprite assets"
```

---

## Self-Review

**Spec coverage:**
- Cross-platform Flutter → Tasks 1, 14. ✓
- Sprite animation (idle/walk/sip) → Tasks 7, 8. ✓
- Transparent always-on-top overlay → Task 2, used in 8/10. ✓
- Custom interval → Tasks 3, 6, 10, 12. ✓
- Configurable snooze → Tasks 3, 6, 10, 12. ✓
- YES/SNOOZE buttons → Task 8. ✓
- Full tracking + history + stats → Tasks 4, 5, 11. ✓
- User music + volume + mute → Tasks 9, 12. ✓
- Menu-bar/tray + dashboard + settings surfaces → Tasks 11, 12, 13. ✓
- Notification fallback → Task 13. ✓
- Computed streaks/trends (not stored) → Task 5. ✓

**Placeholder scan:** No TBD/TODO. Real code in every code step. Sprite art uses explicit placeholder-then-swap steps (Tasks 7, 14) rather than a vague "add art later."

**Type consistency:** `AppSettings` fields, `WaterRepository` method names (`logGlass`, `countForDay`, `allTimestamps`), `WaterStats` statics (`countsByDay`, `currentStreak`, `lastSevenDays`), `CharacterState` values, and `ReminderScheduler` methods (`start`, `reset`, `snooze`, `stop`) are consistent across all tasks that consume them.
