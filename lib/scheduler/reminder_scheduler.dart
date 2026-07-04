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
