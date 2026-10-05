import '../personal_context_engine.dart';
import 'ai_provider.dart';
import 'ai_settings_store.dart';
import 'ai_types.dart';
import 'local_ai_provider.dart';
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

  final List<({String role, String text})> _history = [];

  void clearHistory() => _history.clear();

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

    _history.add((role: 'user', text: userMessage));
    if (result.text.isNotEmpty) {
      _history.add((role: 'assistant', text: result.text));
    }
    while (_history.length > 16) {
      _history.removeAt(0);
    }
    return result;
  }
}
