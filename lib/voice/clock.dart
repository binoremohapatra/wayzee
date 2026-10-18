import 'dart:async';

typedef VoidCallback = void Function();

// Clock abstraction for testing
abstract class Clock {
  Duration get now;
  Timer schedule(Duration duration, VoidCallback callback);
}

// Real clock implementation
class RealClock implements Clock {
  final DateTime _start = DateTime.now();

  @override
  Duration get now => DateTime.now().difference(_start);

  @override
  Timer schedule(Duration duration, VoidCallback callback) {
    return Timer(duration, callback);
  }
}

// Fake clock for testing
class FakeClock implements Clock {
  Duration _currentTime = Duration.zero;
  final List<_ScheduledTask> _tasks = [];

  @override
  Duration get now => _currentTime;

  @override
  Timer schedule(Duration duration, VoidCallback callback) {
    final task = _ScheduledTask(
      executeAt: _currentTime + duration,
      callback: callback,
    );
    _tasks.add(task);
    _tasks.sort((a, b) => a.executeAt.compareTo(b.executeAt));
    return _FakeTimer(this, task);
  }

  void advance(Duration duration) {
    _currentTime += duration;
    while (_tasks.isNotEmpty && _tasks.first.executeAt <= _currentTime) {
      final task = _tasks.removeAt(0);
      if (task.isActive) {
        task.isActive = false;
        task.callback();
      }
    }
  }
}

class _ScheduledTask {
  final Duration executeAt;
  final VoidCallback callback;
  bool isActive = true;

  _ScheduledTask({required this.executeAt, required this.callback});
}

class _FakeTimer implements Timer {
  final FakeClock _clock;
  final _ScheduledTask _task;

  _FakeTimer(this._clock, this._task);

  @override
  void cancel() {
    _task.isActive = false;
    _clock._tasks.remove(_task);
  }

  @override
  bool get isActive => _task.isActive;

  @override
  int get tick => 0;
}
