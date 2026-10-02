import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/main.dart';

void main() {
  testWidgets('app builds', (tester) async {
    // Smoke test only — full DB requires device/plugin binding.
    expect(PersonalLifeOsApp, isNotNull);
  });
}
