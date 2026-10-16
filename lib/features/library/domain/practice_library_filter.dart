import '../../../domain/practice_source/practice_source.dart';

enum LibraryCompletionFilter { all, pending, completed }

enum LibraryPlanFilter { all, planned, unplanned }

/// A stable, UI-independent definition of the practice-library filters.
class PracticeLibraryFilter {
  const PracticeLibraryFilter({
    this.platform,
    this.completion = LibraryCompletionFilter.all,
    this.plan = LibraryPlanFilter.all,
  });

  final SourcePlatform? platform;
  final LibraryCompletionFilter completion;
  final LibraryPlanFilter plan;

  int get activeCount {
    return (platform == null ? 0 : 1) +
        (completion == LibraryCompletionFilter.all ? 0 : 1) +
        (plan == LibraryPlanFilter.all ? 0 : 1);
  }

  bool get isActive => activeCount > 0;

  bool matches(PracticeSource source, {required bool hasPlan}) {
    if (platform != null && source.platform != platform) return false;
    if (completion == LibraryCompletionFilter.pending && source.isCompleted) {
      return false;
    }
    if (completion == LibraryCompletionFilter.completed &&
        !source.isCompleted) {
      return false;
    }
    if (plan == LibraryPlanFilter.planned && !hasPlan) return false;
    if (plan == LibraryPlanFilter.unplanned && hasPlan) return false;
    return true;
  }
}
