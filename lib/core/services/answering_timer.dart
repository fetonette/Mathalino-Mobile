import 'package:flutter/foundation.dart';

/// Tracks active answering duration for a single gameplay level attempt.
///
/// Features monotonic elapsed-time accumulation via [Stopwatch], idempotency on
/// start, pause/resume coordination for overlays and app lifecycle, and clean
/// separation between genuinely recorded 0-second duration and unstarted/missing duration.
class AnsweringTimer {
  final Stopwatch _stopwatch;
  Duration _testOffset = Duration.zero;

  bool _hasStarted = false;
  bool _isPaused = false;
  bool _isStopped = false;

  AnsweringTimer({Stopwatch? stopwatch})
      : _stopwatch = stopwatch ?? Stopwatch();

  /// Whether the student has initiated an answer interaction in this attempt.
  bool get hasStarted => _hasStarted;

  /// Whether the timer is actively running and accumulating time.
  bool get isRunning => _stopwatch.isRunning;

  /// Whether the timer is currently paused (e.g. feedback dialog or app backgrounded).
  bool get isPaused => _isPaused;

  /// Whether the timer has permanently stopped for this attempt.
  bool get isStopped => _isStopped;

  /// Accumulated active answering duration.
  Duration get elapsedDuration => _stopwatch.elapsed + _testOffset;

  /// Active answering duration in whole seconds.
  ///
  /// Returns null if the timer was never started (distinguishing unstarted/missing
  /// from a genuinely recorded 0-second duration).
  int? get elapsedSeconds {
    if (!_hasStarted) return null;
    final sec = elapsedDuration.inSeconds;
    return sec < 0 ? 0 : sec;
  }

  /// Starts the timer on the FIRST answer interaction in the attempt.
  ///
  /// Subsequent calls during the same attempt are no-ops and never restart
  /// or duplicate the timer.
  void startOnFirstInteraction() {
    if (_isStopped || _hasStarted) return;
    _hasStarted = true;
    _isPaused = false;
    _stopwatch.start();
  }

  /// Alias for [startOnFirstInteraction].
  void recordAnswerInteraction() => startOnFirstInteraction();

  /// Pauses timer accumulation (e.g. when app is backgrounded or feedback overlay opens).
  void pause() {
    if (!_hasStarted || _isPaused || _isStopped) return;
    _stopwatch.stop();
    _isPaused = true;
  }

  /// Resumes timer accumulation when returning to active gameplay.
  void resume() {
    if (!_hasStarted || !_isPaused || _isStopped) return;
    _stopwatch.start();
    _isPaused = false;
  }

  /// Permanently stops timer accumulation for the current attempt.
  void stop() {
    if (!_hasStarted || _isStopped) {
      _isStopped = true;
      return;
    }
    _stopwatch.stop();
    _isStopped = true;
    _isPaused = false;
  }

  /// Resets all state for a fresh attempt or level session.
  void reset() {
    _stopwatch.stop();
    _stopwatch.reset();
    _testOffset = Duration.zero;
    _hasStarted = false;
    _isPaused = false;
    _isStopped = false;
  }

  /// Allows test harnesses to advance elapsed time deterministically.
  @visibleForTesting
  void debugAddElapsed(Duration offset) {
    _testOffset += offset;
  }
}
