import 'package:fake_async/fake_async.dart';
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

  test('rescheduling before fire cancels the pending timer (no double-fire)',
      () {
    fakeAsync((async) {
      var fired = 0;
      final s = ReminderScheduler(onFire: () => fired++);
      s.start(const Duration(minutes: 45));

      async.elapse(const Duration(minutes: 20));
      expect(fired, equals(0));

      s.start(const Duration(minutes: 45));

      async.elapse(const Duration(minutes: 30));
      expect(fired, equals(0));

      async.elapse(const Duration(minutes: 15));
      expect(fired, equals(1));
    });
  });

  test('reset reschedules with a new interval', () {
    fakeAsync((async) {
      var fired = 0;
      final s = ReminderScheduler(onFire: () => fired++);
      s.start(const Duration(minutes: 45));

      async.elapse(const Duration(minutes: 20));
      s.reset(const Duration(minutes: 60));

      async.elapse(const Duration(minutes: 44));
      expect(fired, equals(0));

      async.elapse(const Duration(minutes: 16));
      expect(fired, equals(1));
    });
  });
}
