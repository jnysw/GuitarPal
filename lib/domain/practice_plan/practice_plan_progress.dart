import '../practice_session/practice_session.dart';
import 'practice_plan.dart';

class PracticePlanProgress {
  PracticePlanProgress({
    required this.plan,
    required Iterable<PracticeSession> sessions,
  }) : sessions = List.unmodifiable(
         sessions.where(
           (session) =>
               session.planId == plan.id &&
               session.sourceId == plan.sourceId &&
               session.segmentId == plan.segmentId &&
               session.hasPracticeActivity,
         ),
       );

  final PracticePlan plan;
  final List<PracticeSession> sessions;

  int get completedLoops {
    return sessions.fold(0, (total, session) => total + session.loopCount);
  }

  Duration get completedDuration {
    return sessions.fold(
      Duration.zero,
      (total, session) => total + session.activeDuration,
    );
  }

  int get completedValue => switch (plan.goal.type) {
    PracticeGoalType.loops => completedLoops,
    PracticeGoalType.duration => completedDuration.inMilliseconds,
  };

  double get fraction {
    return (completedValue / plan.goal.targetValue).clamp(0.0, 1.0);
  }

  bool get isComplete => completedValue >= plan.goal.targetValue;
}
