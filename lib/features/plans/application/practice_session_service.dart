import 'package:uuid/uuid.dart';

import '../../../domain/practice_plan/calendar_date.dart';
import '../../../domain/practice_plan/practice_plan.dart';
import '../../../domain/practice_session/practice_session.dart';
import '../../../domain/practice_session/practice_session_repository.dart';
import 'practice_playback_session_recorder.dart';

class PracticeSessionService {
  PracticeSessionService(
    this._repository, {
    this._uuid = const Uuid(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final PracticeSessionRepository _repository;
  final Uuid _uuid;
  final DateTime Function() _clock;

  PracticePlaybackSessionRecorder trackPlayback({
    required String sourceId,
    String? planId,
    String? segmentId,
  }) {
    return PracticePlaybackSessionRecorder(
      _repository,
      sourceId: sourceId,
      planId: planId,
      segmentId: segmentId,
      uuid: _uuid,
      clock: _clock,
    );
  }

  Future<PracticeSession> record({
    required PracticePlan plan,
    required Duration activeDuration,
    required int loopCount,
  }) async {
    if (activeDuration.isNegative) {
      throw const FormatException('练习时长不能为负数');
    }
    if (loopCount < 0) {
      throw const FormatException('循环次数不能为负数');
    }
    if (activeDuration == Duration.zero && loopCount == 0) {
      throw const FormatException('请输入本次练习时长或循环次数');
    }

    final localNow = _clock();
    final endedAt = localNow.toUtc();
    final session = PracticeSession(
      id: _uuid.v4(),
      planId: plan.id,
      sourceId: plan.sourceId,
      segmentId: plan.segmentId,
      practiceDate: CalendarDate.fromDateTime(localNow),
      startedAt: endedAt.subtract(activeDuration),
      endedAt: endedAt,
      activeDuration: activeDuration,
      loopCount: loopCount,
      completed: true,
    );
    await _repository.save(session);
    return session;
  }
}
