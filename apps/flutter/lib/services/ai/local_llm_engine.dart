import 'dart:async';
import 'dart:io' show File, Platform;

import 'package:flutter/foundation.dart';

import 'ai_types.dart';
import 'local_llm_bridge_stub.dart'
    if (dart.library.io) 'local_llm_bridge_io.dart' as bridge;

enum LlmEngineStatus { idle, loading, ready, generating, error }

/// On-device GGUF inference via llama.cpp (Android/iOS).
class LocalLlmEngine {
  LocalLlmEngine._();
  static final instance = LocalLlmEngine._();

  dynamic _controller;
  String? _loadedPath;
  String? _loadedLabel;
  bool _loading = false;
  bool _generating = false;
  String? _lastError;
  LlmEngineStatus _status = LlmEngineStatus.idle;

  final _statusCtrl = StreamController<LlmEngineStatus>.broadcast();
  StreamSubscription<String>? _genSub;

  Stream<LlmEngineStatus> get statusStream => _statusCtrl.stream;
  LlmEngineStatus get status => _status;

  bool get isSupported {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  bool get isLoaded => _controller != null && _loadedPath != null;
  bool get isGenerating => _generating;
  bool get isLoading => _loading;
  String? get loadedPath => _loadedPath;
  String? get loadedLabel => _loadedLabel;
  String? get lastError => _lastError;

  void _setStatus(LlmEngineStatus s) {
    _status = s;
    if (!_statusCtrl.isClosed) _statusCtrl.add(s);
  }

  Future<bool> ensureLoaded(AiSettings settings) async {
    if (!isSupported) {
      _lastError = 'On-device LLM requires Android or iOS';
      _setStatus(LlmEngineStatus.error);
      return false;
    }
    final path = settings.localModelPath.trim();
    if (path.isEmpty) {
      _lastError = 'No GGUF model selected. Pick a .gguf file in AI settings.';
      _setStatus(LlmEngineStatus.error);
      return false;
    }
    if (!await File(path).exists()) {
      _lastError =
          'Model file not found. Re-import the .gguf (app storage path may have changed).';
      _setStatus(LlmEngineStatus.error);
      return false;
    }
    if (isLoaded && _loadedPath == path && !_loading) return true;
    if (_loading) {
      _lastError = 'Model is already loading';
      return false;
    }
    return loadModel(
      path: path,
      label: settings.localModelLabel,
      threads: settings.threads,
      contextSize: settings.contextSize,
    );
  }

  Future<bool> loadModel({
    required String path,
    String? label,
    int threads = 4,
    int contextSize = 2048,
  }) async {
    if (!isSupported) {
      _lastError = 'On-device LLM requires Android or iOS';
      _setStatus(LlmEngineStatus.error);
      return false;
    }
    if (_loading) {
      _lastError = 'Model is already loading';
      return false;
    }
    if (_generating) {
      await stop();
    }
    _loading = true;
    _lastError = null;
    _setStatus(LlmEngineStatus.loading);
    try {
      await unload(silent: true);
      final llama = bridge.createLlamaController();
      int? gpuLayers;
      try {
        final gpu = await llama.detectGpu();
        gpuLayers = gpu.recommendedGpuLayers as int?;
      } catch (_) {
        gpuLayers = null;
      }
      await llama.loadModel(
        modelPath: path,
        threads: threads.clamp(1, 8),
        contextSize: contextSize.clamp(512, 4096),
        gpuLayers: gpuLayers,
      );
      _controller = llama;
      _loadedPath = path;
      _loadedLabel = (label != null && label.isNotEmpty)
          ? label
          : path.split(RegExp(r'[/\\]')).last;
      _loading = false;
      _setStatus(LlmEngineStatus.ready);
      return true;
    } catch (e) {
      _lastError = 'Failed to load model: $e';
      _controller = null;
      _loadedPath = null;
      _loadedLabel = null;
      _loading = false;
      _setStatus(LlmEngineStatus.error);
      return false;
    }
  }

  Future<void> unload({bool silent = false}) async {
    await stop();
    try {
      if (_controller != null) {
        await _controller.dispose();
      }
    } catch (_) {}
    _controller = null;
    _loadedPath = null;
    _loadedLabel = null;
    if (!silent) {
      _setStatus(LlmEngineStatus.idle);
    }
  }

  Future<void> stop() async {
    try {
      await _genSub?.cancel();
    } catch (_) {}
    _genSub = null;
    try {
      if (_controller != null && _generating) {
        await _controller.stop();
      }
    } catch (_) {}
    _generating = false;
    if (isLoaded) {
      _setStatus(LlmEngineStatus.ready);
    }
  }

  Future<String> complete({
    required String prompt,
    int maxTokens = 512,
    double temperature = 0.4,
  }) async {
    final buf = StringBuffer();
    await for (final t in stream(
      prompt: prompt,
      maxTokens: maxTokens,
      temperature: temperature,
    )) {
      buf.write(t);
    }
    return buf.toString().trim();
  }

  Stream<String> stream({
    required String prompt,
    int maxTokens = 512,
    double temperature = 0.4,
  }) {
    if (_controller == null) {
      return Stream.error(StateError(_lastError ?? 'Model not loaded'));
    }
    if (_generating) {
      return Stream.error(StateError('Already generating'));
    }
    _generating = true;
    _setStatus(LlmEngineStatus.generating);

    final controller = StreamController<String>();
    try {
      final raw = _controller.generate(
        prompt: prompt,
        maxTokens: maxTokens.clamp(64, 1024),
        temperature: temperature.clamp(0.0, 1.5),
        topP: 0.9,
        repeatPenalty: 1.15,
      ) as Stream<String>;

      _genSub = raw.listen(
        (token) {
          if (!controller.isClosed) controller.add(token);
        },
        onError: (Object e, StackTrace st) {
          _generating = false;
          _lastError = '$e';
          _setStatus(LlmEngineStatus.error);
          if (!controller.isClosed) {
            controller.addError(e, st);
            controller.close();
          }
        },
        onDone: () {
          _generating = false;
          _setStatus(isLoaded ? LlmEngineStatus.ready : LlmEngineStatus.idle);
          if (!controller.isClosed) controller.close();
        },
        cancelOnError: true,
      );
    } catch (e) {
      _generating = false;
      _lastError = '$e';
      _setStatus(LlmEngineStatus.error);
      scheduleMicrotask(() {
        if (!controller.isClosed) {
          controller.addError(e);
          controller.close();
        }
      });
    }
    return controller.stream;
  }
}
