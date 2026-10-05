import '../personal_context_engine.dart';
import 'ai_provider.dart';
import 'ai_types.dart';
import 'local_llm_engine.dart';
import 'prompt_builder.dart';

/// On-device GGUF model grounded in [PersonalSituation].
class OnDeviceLlmProvider implements AiProvider {
  @override
  String get id => 'on_device_llm';

  @override
  Future<AiReply> complete({
    required String userMessage,
    required PersonalSituation situation,
    required AiSettings settings,
    List<({String role, String text})> history = const [],
  }) async {
    final engine = LocalLlmEngine.instance;
    final ok = await engine.ensureLoaded(settings);
    if (!ok) {
      return AiReply(
        text: '',
        source: AiSource.onDevice,
        error: engine.lastError ?? 'On-device model not ready',
      );
    }

    final situationBlock = AiPromptBuilder.situationBlock(situation);
    final hist = StringBuffer();
    for (final h in history.take(6)) {
      hist.writeln('${h.role == 'user' ? 'User' : 'Assistant'}: ${h.text}');
    }

    final prompt = '''
<|im_start|>system
${settings.systemPreamble}

$situationBlock
<|im_end|>
${hist.isEmpty ? '' : hist.toString()}
<|im_start|>user
$userMessage
<|im_end|>
<|im_start|>assistant
''';

    try {
      final text = await engine.complete(
        prompt: prompt,
        maxTokens: settings.maxTokens,
        temperature: 0.4,
      );
      if (text.isEmpty) {
        return AiReply(
          text: '',
          source: AiSource.onDevice,
          model: settings.localModelLabel.isEmpty
              ? settings.localModelPath
              : settings.localModelLabel,
          error: 'Model returned empty text',
        );
      }
      return AiReply(
        text: text,
        source: AiSource.onDevice,
        model: settings.localModelLabel.isEmpty
            ? 'local-gguf'
            : settings.localModelLabel,
        usedSituation: true,
      );
    } catch (e) {
      return AiReply(
        text: '',
        source: AiSource.onDevice,
        error: 'On-device generation failed: $e',
      );
    }
  }
}
