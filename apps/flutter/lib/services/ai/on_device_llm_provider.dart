import '../personal_context_engine.dart';
import 'ai_provider.dart';
import 'ai_types.dart';
import 'local_llm_engine.dart';
import 'prompt_builder.dart';

/// On-device GGUF model grounded in [PersonalSituation].
class OnDeviceLlmProvider implements AiProvider {
  @override
  String get id => 'on_device_llm';

  String buildPrompt({
    required String userMessage,
    required PersonalSituation situation,
    required AiSettings settings,
    List<({String role, String text})> history = const [],
  }) {
    final situationBlock = AiPromptBuilder.situationBlockCompact(situation);
    final hist = StringBuffer();
    for (final h in history.take(4)) {
      final role = h.role == 'user' ? 'user' : 'assistant';
      final text = h.text.length > 400 ? '${h.text.substring(0, 400)}…' : h.text;
      hist.writeln('<|im_start|>$role\n$text\n<|im_end|>');
    }
    final user = userMessage.length > 800
        ? '${userMessage.substring(0, 800)}…'
        : userMessage;

    return '''
<|im_start|>system
${settings.systemPreamble}

$situationBlock
Answer in plain language. Prefer concrete next actions from OPPORTUNITY/PRIORITY.
If unsure, say so — do not invent tasks, balances, or appointments.
<|im_end|>
$hist<|im_start|>user
$user
<|im_end|>
<|im_start|>assistant
''';
  }

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

    final prompt = buildPrompt(
      userMessage: userMessage,
      situation: situation,
      settings: settings,
      history: history,
    );

    try {
      final text = await engine.complete(
        prompt: prompt,
        maxTokens: settings.maxTokens.clamp(64, 768),
        temperature: 0.35,
      );
      final cleaned = _stripSpecialTokens(text);
      if (cleaned.isEmpty) {
        return AiReply(
          text: '',
          source: AiSource.onDevice,
          model: engine.loadedLabel ?? 'local-gguf',
          error: 'Model returned empty text',
        );
      }
      return AiReply(
        text: cleaned,
        source: AiSource.onDevice,
        model: engine.loadedLabel ?? 'local-gguf',
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

  Stream<String> streamTokens({
    required String userMessage,
    required PersonalSituation situation,
    required AiSettings settings,
    List<({String role, String text})> history = const [],
  }) async* {
    final engine = LocalLlmEngine.instance;
    final ok = await engine.ensureLoaded(settings);
    if (!ok) {
      throw StateError(engine.lastError ?? 'On-device model not ready');
    }
    final prompt = buildPrompt(
      userMessage: userMessage,
      situation: situation,
      settings: settings,
      history: history,
    );
    await for (final t in engine.stream(
      prompt: prompt,
      maxTokens: settings.maxTokens.clamp(64, 768),
      temperature: 0.35,
    )) {
      yield t;
    }
  }

  String _stripSpecialTokens(String text) {
    var t = text.trim();
    for (final s in [
      '<|im_end|>',
      '<|im_start|>',
      '<|end|>',
      '<|endoftext|>',
      '</s>',
      '<s>',
    ]) {
      t = t.replaceAll(s, '');
    }
    return t.trim();
  }
}
