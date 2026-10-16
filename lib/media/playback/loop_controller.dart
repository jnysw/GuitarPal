class LoopRange {
  LoopRange({required this.start, required this.end}) {
    if (start.isNegative) {
      throw ArgumentError.value(start, 'start', 'must not be negative');
    }
    if (end <= start) {
      throw ArgumentError.value(end, 'end', 'must be after start');
    }
  }

  final Duration start;
  final Duration end;
}

class LoopController {
  LoopController({this.tolerance = const Duration(milliseconds: 180)});

  final Duration tolerance;

  Duration? _start;
  Duration? _end;
  bool _enabled = false;
  int _completedLoops = 0;
  int _totalCompletedLoops = 0;
  bool _loopArmed = true;

  Duration? get start => _start;
  Duration? get end => _end;
  bool get enabled => _enabled;
  int get completedLoops => _completedLoops;
  int get totalCompletedLoops => _totalCompletedLoops;

  LoopRange? get range {
    final start = _start;
    final end = _end;
    if (start == null || end == null || end <= start) return null;
    return LoopRange(start: start, end: end);
  }

  void setStart(Duration position) {
    if (position.isNegative) {
      throw ArgumentError.value(position, 'position', 'must not be negative');
    }
    _start = position;
    if (_end case final end? when end <= position) {
      _end = null;
      _enabled = false;
    }
    _completedLoops = 0;
    _loopArmed = true;
  }

  bool setEnd(Duration position, {Duration? duration}) {
    final start = _start;
    if (start == null || position <= start) return false;
    if (duration != null && position > duration) return false;
    _end = position;
    _completedLoops = 0;
    _loopArmed = true;
    return true;
  }

  bool setEnabled(bool value) {
    if (value && range == null) return false;
    _enabled = value;
    if (value) _loopArmed = true;
    return true;
  }

  void setRange(LoopRange value, {bool enabled = true}) {
    _start = value.start;
    _end = value.end;
    _enabled = enabled;
    _completedLoops = 0;
    _loopArmed = true;
  }

  Duration? seekTargetFor(Duration position) {
    final activeRange = range;
    if (!_enabled || activeRange == null) return null;
    if (position < activeRange.end - tolerance) {
      _loopArmed = true;
      return null;
    }
    if (!_loopArmed) return null;
    _loopArmed = false;
    _completedLoops += 1;
    _totalCompletedLoops += 1;
    return activeRange.start;
  }

  void clear() {
    _start = null;
    _end = null;
    _enabled = false;
    _completedLoops = 0;
    _loopArmed = true;
  }
}
