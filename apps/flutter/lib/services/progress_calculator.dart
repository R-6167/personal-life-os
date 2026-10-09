/// Shared, deterministic completion math for goal and project workspaces.
///
/// Recent focus time is a separate signal; it must not increase completion
/// percentages because time invested does not prove that work was completed.
class ProgressCalculator {
  ProgressCalculator._();

  static double completionRatio({required int done, required int total}) {
    if (total <= 0) return 0;
    return (done / total).clamp(0.0, 1.0);
  }

  /// Tasks carry most of a project's progress; milestones provide checkpoints.
  /// If only one kind of work exists, it owns the full ratio so a project can
  /// still reach 100% without requiring both tasks and milestones.
  static double projectRatio({
    required int tasksDone,
    required int tasksTotal,
    required int milestonesDone,
    required int milestonesTotal,
  }) {
    final hasTasks = tasksTotal > 0;
    final hasMilestones = milestonesTotal > 0;
    if (!hasTasks && !hasMilestones) return 0;
    final taskRatio = completionRatio(done: tasksDone, total: tasksTotal);
    final milestoneRatio = completionRatio(done: milestonesDone, total: milestonesTotal);
    if (hasTasks && hasMilestones) {
      return (taskRatio * 0.7 + milestoneRatio * 0.3).clamp(0.0, 1.0);
    }
    return hasTasks ? taskRatio : milestoneRatio;
  }

  /// Goal progress averages supporting project progress and direct goal tasks.
  /// Tasks already represented inside a supporting project must not be counted
  /// again as direct goal tasks. Habits are reported separately as consistency
  /// evidence, since a single completed occurrence is not goal completion.
  static double goalRatio({
    required List<double> projectRatios,
    required int directTasksDone,
    required int directTasksTotal,
  }) {
    final hasProjects = projectRatios.isNotEmpty;
    final hasDirectTasks = directTasksTotal > 0;
    if (!hasProjects && !hasDirectTasks) return 0;
    final projectRatio = hasProjects
        ? projectRatios.reduce((a, b) => a + b) / projectRatios.length
        : 0.0;
    final directTaskRatio = completionRatio(done: directTasksDone, total: directTasksTotal);
    if (hasProjects && hasDirectTasks) {
      return (projectRatio * 0.6 + directTaskRatio * 0.4).clamp(0.0, 1.0);
    }
    return hasProjects ? projectRatio : directTaskRatio;
  }
}
