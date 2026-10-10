// Test the task title remains stable across an edit-form rebuild.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/data/database.dart';
import 'package:ordin/data/task_repository.dart';
import 'package:ordin/ui/screens/task_detail_screen.dart';
import 'helpers/test_db.dart';

void main() {
  setUp(() async => openTestDb());
  tearDown(() async => closeTestDb());

  testWidgets('task title remains editable while focus and rebuilds occur',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final task = await TaskRepository(AppDatabase.instance)
        .create(title: 'Original task title');
    await tester.pumpWidget(MaterialApp(home: TaskDetailScreen(taskId: task.id)));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Original task title'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.edit));
    await tester.pump();
    final titleField = find.byType(TextField).first;
    await tester.tap(titleField);
    await tester.enterText(titleField, 'Edited task title');
    await tester.pump();
    expect(tester.widget<TextField>(titleField).controller!.text,
        'Edited task title');

    // Use bounded pumping because the detail screen may keep animations alive.
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('High'), findsWidgets);
    await tester.tap(find.text('High').last);
    await tester.pump();
    expect(tester.widget<TextField>(titleField).controller!.text,
        'Edited task title');
  });
}
