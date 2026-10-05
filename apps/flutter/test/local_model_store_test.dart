import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/services/ai/local_model_store.dart';

void main() {
  group('LocalModelStore.formatBytes', () {
    test('scales units', () {
      expect(LocalModelStore.formatBytes(500), '500 B');
      expect(LocalModelStore.formatBytes(2048), contains('KB'));
      expect(LocalModelStore.formatBytes(5 * 1024 * 1024), contains('MB'));
      expect(
        LocalModelStore.formatBytes(2 * 1024 * 1024 * 1024),
        contains('GB'),
      );
    });
  });
}
