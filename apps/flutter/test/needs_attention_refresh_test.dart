import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/ui/screens/needs_attention_screen.dart';
import 'helpers/test_db.dart';

void main() {
  setUp(() async => openTestDb());
  tearDown(() async => closeTestDb());

  testWidgets('needs-attention screen stays available during refresh', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: NeedsAttentionScreen()));
    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();
    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
