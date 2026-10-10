import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/ui/screens/project_detail_screen.dart';
import 'package:ordin/data/project_repository.dart';
import 'package:ordin/data/database.dart';

import 'helpers/test_db.dart';

void main() {
  setUp(() async {
    await openTestDb();
  });

  tearDown(() async {
    await closeTestDb();
  });

  testWidgets('project workspace remains visible while scrolling', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final project = await ProjectRepository(AppDatabase.instance).create(
      title: 'Workspace scroll regression',
    );
    await tester.pumpWidget(
      MaterialApp(home: ProjectDetailScreen(projectId: project.id)),
    );
    for (var i = 0;
        i < 40 && find.text('Workspace scroll regression').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Workspace scroll regression'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Workspace scroll regression'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
  });
}
