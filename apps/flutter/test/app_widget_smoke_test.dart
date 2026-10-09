import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/ui/home_shell.dart';

import 'helpers/test_db.dart';

void main() {
  setUp(() async {
    await openTestDb();
  });

  tearDown(() async {
    await closeTestDb();
  });

  testWidgets('home shell boots and exposes all primary destinations',
      (tester) async {
    await tester.view.setPhysicalSize(const Size(1080, 1920));
    await tester.view.setDevicePixelRatio(1);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: HomeShell()));

    // Boot includes asynchronous database setup and best-effort notification
    // synchronization. Pump in bounded steps instead of relying on an
    // unbounded settle while the initial loading indicator is visible.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Today'), findsWidgets);

    for (final destination in ['Tasks', 'Life', 'Finance', 'More']) {
      await tester.tap(find.text(destination).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(destination),
        ),
        findsOneWidget,
        reason: 'Selecting $destination should update the active screen title',
      );
      expect(find.byType(NavigationBar), findsOneWidget);
    }

    // Returning to Today should remain possible after traversing every tab.
    await tester.tap(find.text('Today').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Today'),
      ),
      findsOneWidget,
    );
  });
}
