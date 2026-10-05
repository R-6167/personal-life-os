import 'ai_types.dart';
import '../personal_context_engine.dart';

abstract class AiProvider {
  String get id;
  Future<AiReply> complete({
    required String userMessage,
    required PersonalSituation situation,
    required AiSettings settings,
    List<({String role, String text})> history = const [],
  });
}
