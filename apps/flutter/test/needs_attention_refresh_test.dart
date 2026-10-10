import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/ui/screens/needs_attention_screen.dart';

import 'helpers/test_db.dart';

void main() {
  setUp(() async {
    await openTestDb();
  });

  tearDown(() async {
    await closeTestDb();
  });

  testWidgets('needs-attention feed remains visible after refresh', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: NeedsAttentionScreen()),
    );

    for (var i = 0; i < 60 && find.text('Nothing urgent').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Nothing urgent'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();
    for (var i = 0; i < 60 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Nothing urgent'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
  });
}
