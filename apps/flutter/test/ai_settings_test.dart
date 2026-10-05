import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/services/ai/ai_types.dart';

void main() {
  group('AiSettings', () {
    test('round-trip json preserves mode and model path', () {
      final s = AiSettings(
        mode: AiMode.onDeviceWithFallback,
        baseUrl: 'https://api.example.com/v1',
        apiKey: 'secret',
        model: 'gpt-test',
        localModelPath: '/data/models/phi.gguf',
        localModelLabel: 'phi.gguf',
        contextSize: 2048,
        threads: 4,
        maxTokens: 256,
      );
      final back = AiSettings.fromJson(s.toJson());
      expect(back.mode, AiMode.onDeviceWithFallback);
      expect(back.localModelPath, '/data/models/phi.gguf');
      expect(back.localModelLabel, 'phi.gguf');
      expect(back.remoteConfigured, isTrue);
      expect(back.localModelConfigured, isTrue);
    });

    test('default is localOnly offline', () {
      final s = AiSettings();
      expect(s.mode, AiMode.localOnly);
      expect(s.remoteConfigured, isFalse);
      expect(s.localModelConfigured, isFalse);
    });

    test('unknown mode falls back to localOnly', () {
      final s = AiSettings.fromJson({'mode': 'not_a_real_mode'});
      expect(s.mode, AiMode.localOnly);
    });
  });

  group('AiReply', () {
    test('ok requires text and no error', () {
      expect(AiReply(text: 'hi', source: AiSource.local).ok, isTrue);
      expect(AiReply(text: '', source: AiSource.local).ok, isFalse);
      expect(
        AiReply(text: 'x', source: AiSource.onDevice, error: 'e').ok,
        isFalse,
      );
    });
  });
}
