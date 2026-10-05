import '../intelligence_assistant.dart';
import '../personal_context_engine.dart';
import 'ai_provider.dart';
import 'ai_types.dart';

/// Deterministic local reasoning — always available offline.
class LocalAiProvider implements AiProvider {
  LocalAiProvider({IntelligenceAssistant? assistant})
      : _assistant = assistant ?? IntelligenceAssistant();

  final IntelligenceAssistant _assistant;

  @override
  String get id => 'local';

  @override
  Future<AiReply> complete({
    required String userMessage,
    required PersonalSituation situation,
    required AiSettings settings,
    List<({String role, String text})> history = const [],
  }) async {
    final q = userMessage.trim().toLowerCase();
    if (q.isEmpty ||
        q.contains('situation') ||
        q.contains('context') ||
        q.contains('capacity') ||
        q.contains('pressure') ||
        q.contains('today') ||
        q.contains('focus') ||
        q.contains('brief') ||
        q.contains('summary') ||
        q.contains('where am i')) {
      return AiReply(
        text: situation.narrative(),
        source: AiSource.local,
        model: 'personal-context-engine',
        usedSituation: true,
      );
    }
    final text = await _assistant.reply(userMessage);
    return AiReply(
      text: text,
      source: AiSource.local,
      model: 'intelligence-assistant',
      usedSituation: true,
    );
  }
}
