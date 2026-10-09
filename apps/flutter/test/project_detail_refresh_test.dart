import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/data/database.dart';
import 'package:ordin/ui/screens/project_detail_screen.dart';

import 'helpers/test_db.dart';

void main() {
  setUp(() async {
    await openTestDb();
  });

  tearDown(() async {
    await closeTestDb();
  });

  testWidgets('refreshing project after adding a milestone keeps workspace visible',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final app = AppDatabase.instance;
    final db = await app.database;
    final ownerId = await app.requireOwnerId();
    final now = AppDatabase.nowMs();
    const projectId = 'project-refresh-regression';

    await db.insert('projects', {
      'id': projectId,
      'owner_id': ownerId,
      'title': 'Keep this workspace visible',
      'status': 'ACTIVE',
      'created_at': now,
      'updated_at': now,
    });

    await tester.pumpWidget(
      MaterialApp(home: ProjectDetailScreen(projectId: projectId)),
    );
    for (var i = 0; i < 30 && find.text('Keep this workspace visible').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Keep this workspace visible'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.ensureVisible(find.text('Milestones'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Add').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'First milestone');
    await tester.tap(find.text('Save'));
    await tester.pump();

    var sawFullScreenRefresh = false;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      if (find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
        sawFullScreenRefresh = true;
      }
      if (find.text('First milestone').evaluate().isNotEmpty) break;
    }

    expect(find.text('First milestone'), findsOneWidget);
    expect(find.text('Keep this workspace visible'), findsOneWidget);
    expect(
      sawFullScreenRefresh,
      isFalse,
      reason: 'A data refresh should update the project in place, not replace it with a loading screen.',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
  });
}
