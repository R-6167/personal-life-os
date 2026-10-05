import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../personal_context_engine.dart';
import 'ai_provider.dart';
import 'ai_types.dart';
import 'prompt_builder.dart';

/// OpenAI-compatible chat completions (optional).
/// Requires network + INTERNET permission when enabled.
class RemoteAiProvider implements AiProvider {
  @override
  String get id => 'remote';

  @override
  Future<AiReply> complete({
    required String userMessage,
    required PersonalSituation situation,
    required AiSettings settings,
    List<({String role, String text})> history = const [],
  }) async {
    if (!settings.remoteConfigured) {
      return AiReply(
        text: '',
        source: AiSource.remote,
        error: 'Remote AI not configured (base URL + API key).',
      );
    }

    final base = settings.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse(
      base.endsWith('/chat/completions') ? base : '$base/chat/completions',
    );

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': settings.systemPreamble},
      {
        'role': 'system',
        'content': AiPromptBuilder.situationBlock(situation),
      },
    ];
    for (final h in history.take(8)) {
      messages.add({
        'role': h.role == 'user' ? 'user' : 'assistant',
        'content': h.text,
      });
    }
    messages.add({'role': 'user', 'content': userMessage});

    final body = jsonEncode({
      'model': settings.model,
      'messages': messages,
      'temperature': 0.4,
      'max_tokens': 800,
    });

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 20);
      final req = await client.postUrl(uri);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.headers
          .set(HttpHeaders.authorizationHeader, 'Bearer ${settings.apiKey}');
      req.add(utf8.encode(body));
      final res = await req.close().timeout(const Duration(seconds: 45));
      final raw = await res.transform(utf8.decoder).join();
      client.close(force: true);

      if (res.statusCode < 200 || res.statusCode >= 300) {
        return AiReply(
          text: '',
          source: AiSource.remote,
          model: settings.model,
          error:
              'Remote AI HTTP ${res.statusCode}: ${raw.length > 180 ? raw.substring(0, 180) : raw}',
        );
      }

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final choices = decoded['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        return AiReply(
          text: '',
          source: AiSource.remote,
          model: settings.model,
          error: 'Empty remote response',
        );
      }
      final msg = choices.first['message'] as Map<String, dynamic>?;
      final content = '${msg?['content'] ?? ''}'.trim();
      if (content.isEmpty) {
        return AiReply(
          text: '',
          source: AiSource.remote,
          model: settings.model,
          error: 'Blank model content',
        );
      }
      return AiReply(
        text: content,
        source: AiSource.remote,
        model: settings.model,
        usedSituation: true,
      );
    } on SocketException catch (e) {
      return AiReply(
        text: '',
        source: AiSource.remote,
        error: 'Network unavailable: $e',
      );
    } on TimeoutException {
      return AiReply(
        text: '',
        source: AiSource.remote,
        error: 'Remote AI timed out',
      );
    } catch (e) {
      return AiReply(
        text: '',
        source: AiSource.remote,
        error: 'Remote AI error: $e',
      );
    }
  }
}
