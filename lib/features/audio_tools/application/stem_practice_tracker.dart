import '../../plans/application/practice_playback_session_recorder.dart';

/// One recorder per practice target, independent of stem count, speed and seeks.
class StemPracticeTracker {
  StemPracticeTracker(this.recorder, {int initialNativeLoops = 0})
    : _lastNativeLoops = initialNativeLoops;
  final PracticePlaybackSessionRecorder? recorder;
  int _lastNativeLoops;
  int _loops = 0;
  bool _suspended = false, _closed = false;
  bool _needsLoopBaseline = false;
  Duration get activeDuration => recorder?.activeDuration ?? Duration.zero;
  int get loops => recorder?.completedLoops ?? 0;
  void observe({required bool playing, required int nativeLoops}) {
    if (_closed) return;
    if (!_needsLoopBaseline && !_suspended && nativeLoops >= _lastNativeLoops) {
      _loops += nativeLoops - _lastNativeLoops;
    }
    _needsLoopBaseline = false;
    _lastNativeLoops = nativeLoops;
    recorder?.observe(
      isPlaying: playing && !_suspended,
      completedLoops: _loops,
    );
  }

  void pause() {
    if (!_closed) recorder?.observe(isPlaying: false, completedLoops: _loops);
  }

  void resetNativeCounter() {
    pause();
    _lastNativeLoops = 0;
  }

  void suspend() {
    _suspended = true;
    _needsLoopBaseline = true;
    recorder?.suspend();
  }

  void resume() {
    _suspended = false;
    recorder?.resume();
  }

  Future<void> checkpoint() async {
    if (!_closed) await recorder?.checkpoint();
  }

  Future<void> finish() async {
    if (_closed) return;
    pause();
    await recorder?.finish();
    _closed = true;
  }

  static StemPracticeTracker untracked() => StemPracticeTracker(null);
}
