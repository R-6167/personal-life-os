import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/data/database.dart';
import 'package:ordin/data/goal_repository.dart';
import 'package:ordin/data/habit_repository.dart';
import 'package:ordin/data/milestone_repository.dart';
import 'package:ordin/data/project_repository.dart';
import 'package:ordin/data/task_repository.dart';
import 'package:ordin/domain/enums.dart';
import 'package:ordin/services/life_thread.dart';
import 'package:ordin/services/progress_calculator.dart';
import 'package:ordin/services/project_workspace.dart';

import 'helpers/test_db.dart';

void main() {
  setUp(() async {
    await openTestDb();
  });

  tearDown(() async {
    await closeTestDb();
  });

  test('project progress uses one formula and can reach 100% with one work type', () {
    expect(
      ProgressCalculator.projectRatio(
        tasksDone: 1,
        tasksTotal: 1,
        milestonesDone: 0,
        milestonesTotal: 0,
      ),
      1.0,
    );
    expect(
      ProgressCalculator.projectRatio(
        tasksDone: 0,
        tasksTotal: 0,
        milestonesDone: 2,
        milestonesTotal: 2,
      ),
      1.0,
    );
    expect(
      ProgressCalculator.projectRatio(
        tasksDone: 1,
        tasksTotal: 1,
        milestonesDone: 0,
        milestonesTotal: 1,
      ),
      closeTo(0.7, 0.001),
    );
    expect(
      ProgressCalculator.projectRatio(
        tasksDone: 0,
        tasksTotal: 0,
        milestonesDone: 0,
        milestonesTotal: 0,
      ),
      0.0,
    );
    expect(
      ProgressCalculator.goalRatio(
        projectRatios: [0.7],
        directTasksDone: 1,
        directTasksTotal: 1,
      ),
      closeTo(0.82, 0.001),
    );
  });

  test('project workspace includes tasks with an unset status', () async {
    final app = AppDatabase.instance;
    final project = await ProjectRepository(app).create(title: 'Unknown status project');
    final task = await TaskRepository(app).create(
      title: 'Task with legacy status',
      projectId: project.id,
    );
    await (await app.database).update(
      'tasks',
      {'status': null},
      where: 'id = ?',
      whereArgs: [task.id],
    );

    final workspace = await ProjectWorkspaceService(app).load(project.id);
    final projectThread = await LifeThreadService(app).forProject(project.id);
    final counts = await ProjectRepository(app).progress(project.id);

    expect(workspace.tasksTotal, 1);
    expect(workspace.progressRatio, 0.0);
    expect(projectThread.tasksTotal, 1);
    expect(projectThread.progressRatio, 0.0);
    expect(counts['tasksTotal'], 1);
    expect(counts['tasksDone'], 0);
  });

  test('goal and project workspaces agree and habit completion stays separate', () async {
    final app = AppDatabase.instance;
    final goals = GoalRepository(app);
    final projects = ProjectRepository(app);
    final tasks = TaskRepository(app);
    final milestones = MilestoneRepository(app);
    final habits = HabitRepository(app);
    final now = AppDatabase.nowMs();

    final goal = await goals.create(title: 'Learn a language');
    final project = await projects.create(title: 'Daily practice setup', goalId: goal.id);
    final completedProjectTask = await tasks.create(
      title: 'Create a study plan',
      projectId: project.id,
    );
    await tasks.complete(completedProjectTask.id);
    final archivedTask = await tasks.create(
      title: 'Old archived work',
      projectId: project.id,
    );
    await tasks.complete(archivedTask.id);
    await (await app.database).update(
      'tasks',
      {'archived_at': now},
      where: 'id = ?',
      whereArgs: [archivedTask.id],
    );
    await tasks.create(
      title: 'Cancelled work',
      projectId: project.id,
      status: EntityStatus.cancelled,
    );
    await milestones.create(projectId: project.id, title: 'First checkpoint');

    final directTask = await tasks.create(title: 'Practice today', goalId: goal.id);
    await tasks.complete(directTask.id);

    final habit = await habits.create(title: 'Study for 10 minutes');
    await goals.linkHabit(habit.id, goal.id);
    await habits.markDoneToday(habit.id);

    final workspace = await ProjectWorkspaceService(app).load(project.id);
    final projectThread = await LifeThreadService(app).forProject(project.id);
    final goalThread = await LifeThreadService(app).forGoal(goal.id);
    final goalRatio = await goals.progressRatio(goal.id);
    final goalCounts = await goals.progress(goal.id);
    final projectCounts = await projects.progress(project.id);

    expect(workspace.progressRatio, closeTo(0.7, 0.001));
    expect(projectThread.progressRatio, closeTo(workspace.progressRatio, 0.001));
    expect(goalThread.progressRatio, closeTo(goalRatio, 0.001));
    expect(goalRatio, closeTo(0.82, 0.001));
    expect(workspace.tasksTotal, 1);
    expect(projectCounts['tasksTotal'], 1);
    expect(projectCounts['tasksDone'], 1);
    expect(goalCounts['tasksTotal'], 2);
    expect(goalCounts['tasksDone'], 2);
    expect(goalCounts['habitsTotal'], 1);
    expect(goalCounts['habitsDoneToday'], 1);
    expect(goalThread.habitsDoneToday, 1);
    expect(goalThread.doingSummary, contains('1/1 habits done today'));
  });
}
