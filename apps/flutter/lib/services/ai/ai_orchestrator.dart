import '../personal_context_engine.dart';
import 'ai_provider.dart';
import 'ai_settings_store.dart';
import 'ai_types.dart';
import 'local_ai_provider.dart';
import 'local_llm_engine.dart';
import 'on_device_llm_provider.dart';
import 'remote_ai_provider.dart';

/// Routes user messages through rule engine, on-device LLM, and/or remote.
class AiOrchestrator {
  AiOrchestrator({
    AiProvider? local,
    AiProvider? onDevice,
    AiProvider? remote,
    PersonalContextEngine? contextEngine,
  })  : _local = local ?? LocalAiProvider(),
        _onDevice = onDevice ?? OnDeviceLlmProvider(),
        _remote = remote ?? RemoteAiProvider(),
        _engine = contextEngine ?? PersonalContextEngine();

  final AiProvider _local;
  final AiProvider _onDevice;
  final AiProvider _remote;
  final PersonalContextEngine _engine;
  final OnDeviceLlmProvider _onDeviceTyped = OnDeviceLlmProvider();

  final List<({String role, String text})> _history = [];

  void clearHistory() => _history.clear();

  Future<void> stopGeneration() => LocalLlmEngine.instance.stop();

  Future<AiReply> reply(String userMessage) async {
    final settings = await AiSettingsStore.instance.load();
    final situation = await _engine.build();
    final hist = List<({String role, String text})>.of(_history);

    AiReply result;
    switch (settings.mode) {
      case AiMode.localOnly:
        result = await _local.complete(
          userMessage: userMessage,
          situation: situation,
          settings: settings,
          history: hist,
        );
        break;

      case AiMode.onDeviceLlm:
        result = await _onDevice.complete(
          userMessage: userMessage,
          situation: situation,
          settings: settings,
          history: hist,
        );
        if (!result.ok) {
          result = AiReply(
            text: result.error ?? 'On-device LLM failed.',
            source: AiSource.onDevice,
            error: result.error,
          );
        }
        break;

      case AiMode.onDeviceWithFallback:
        final device = await _onDevice.complete(
          userMessage: userMessage,
          situation: situation,
          settings: settings,
          history: hist,
        );
        if (device.ok) {
          result = device;
        } else {
          final local = await _local.complete(
            userMessage: userMessage,
            situation: situation,
            settings: settings,
            history: hist,
          );
          result = AiReply(
            text: '${local.text}\n\n—\n(Rule engine · on-device: ${device.error})',
            source: AiSource.hybrid,
            model: local.model,
            usedSituation: true,
            error: device.error,
          );
        }
        break;

      case AiMode.remoteOnly:
        result = await _remote.complete(
          userMessage: userMessage,
          situation: situation,
          settings: settings,
          history: hist,
        );
        if (!result.ok) {
          result = AiReply(
            text: result.error ?? 'Remote AI failed.',
            source: AiSource.remote,
            error: result.error,
          );
        }
        break;

      case AiMode.remoteWithFallback:
        if (settings.remoteConfigured) {
          final remote = await _remote.complete(
            userMessage: userMessage,
            situation: situation,
            settings: settings,
            history: hist,
          );
          if (remote.ok) {
            result = AiReply(
              text: remote.text,
              source: AiSource.hybrid,
              model: remote.model,
              usedSituation: true,
            );
          } else {
            final local = await _local.complete(
              userMessage: userMessage,
              situation: situation,
              settings: settings,
              history: hist,
            );
            result = AiReply(
              text: '${local.text}\n\n—\n(Local fallback · remote: ${remote.error})',
              source: AiSource.hybrid,
              model: local.model,
              usedSituation: true,
              error: remote.error,
            );
          }
        } else {
          result = await _local.complete(
            userMessage: userMessage,
            situation: situation,
            settings: settings,
            history: hist,
          );
        }
        break;
    }

    _record(userMessage, result.text);
    return result;
  }

  Stream<String> replyStream(String userMessage) async* {
    final settings = await AiSettingsStore.instance.load();
    final situation = await _engine.build();
    final hist = List<({String role, String text})>.of(_history);

    final useDevice = settings.mode == AiMode.onDeviceLlm ||
        settings.mode == AiMode.onDeviceWithFallback;

    if (useDevice && settings.localModelConfigured) {
      try {
        final buf = StringBuffer();
        await for (final t in _onDeviceTyped.streamTokens(
          userMessage: userMessage,
          situation: situation,
          settings: settings,
          history: hist,
        )) {
          buf.write(t);
          yield t;
        }
        final cleaned = buf.toString().trim();
        if (cleaned.isNotEmpty) {
          _record(userMessage, cleaned);
          return;
        }
        if (settings.mode == AiMode.onDeviceWithFallback) {
          final local = await _local.complete(
            userMessage: userMessage,
            situation: situation,
            settings: settings,
            history: hist,
          );
          yield '\n${local.text}';
          _record(userMessage, local.text);
        }
        return;
      } catch (e) {
        if (settings.mode == AiMode.onDeviceWithFallback) {
          final local = await _local.complete(
            userMessage: userMessage,
            situation: situation,
            settings: settings,
            history: hist,
          );
          yield local.text;
          if (local.text.isNotEmpty) {
            yield '\n\n—(on-device: $e)';
          }
          _record(userMessage, local.text);
          return;
        }
        yield 'On-device LLM failed: $e';
        _record(userMessage, 'On-device LLM failed: $e');
        return;
      }
    }

    final result = await reply(userMessage);
    yield result.text;
  }

  void _record(String user, String assistant) {
    _history.add((role: 'user', text: user));
    if (assistant.isNotEmpty) {
      _history.add((role: 'assistant', text: assistant));
    }
    while (_history.length > 16) {
      _history.removeAt(0);
    }
  }
}
