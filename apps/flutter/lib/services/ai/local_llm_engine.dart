import 'dart:async';
import 'dart:io' show File, Platform;

import 'package:flutter/foundation.dart';

import 'ai_types.dart';
import 'local_llm_bridge_stub.dart'
    if (dart.library.io) 'local_llm_bridge_io.dart' as bridge;

/// On-device GGUF inference via llama.cpp (Android/iOS).
class LocalLlmEngine {
  LocalLlmEngine._();
  static final instance = LocalLlmEngine._();

  dynamic _controller;
  String? _loadedPath;
  bool _loading = false;
  String? _lastError;

  bool get isSupported {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  bool get isLoaded => _controller != null && _loadedPath != null;
  String? get loadedPath => _loadedPath;
  String? get lastError => _lastError;
  bool get isLoading => _loading;

  Future<bool> ensureLoaded(AiSettings settings) async {
    if (!isSupported) {
      _lastError = 'On-device LLM requires Android or iOS';
      return false;
    }
    final path = settings.localModelPath.trim();
    if (path.isEmpty) {
      _lastError = 'No GGUF model selected. Pick a .gguf file in AI settings.';
      return false;
    }
    if (!await File(path).exists()) {
      _lastError = 'Model file not found: $path';
      return false;
    }
    if (isLoaded && _loadedPath == path) return true;
    return loadModel(
      path: path,
      threads: settings.threads,
      contextSize: settings.contextSize,
    );
  }

  Future<bool> loadModel({
    required String path,
    int threads = 4,
    int contextSize = 2048,
  }) async {
    if (!isSupported) {
      _lastError = 'On-device LLM requires Android or iOS';
      return false;
    }
    if (_loading) return false;
    _loading = true;
    _lastError = null;
    try {
      await unload();
      final llama = bridge.createLlamaController();
      await llama.loadModel(
        modelPath: path,
        threads: threads.clamp(1, 8),
        contextSize: contextSize.clamp(512, 8192),
      );
      _controller = llama;
      _loadedPath = path;
      _loading = false;
      return true;
    } catch (e) {
      _lastError = 'Failed to load model: $e';
      _controller = null;
      _loadedPath = null;
      _loading = false;
      return false;
    }
  }

  Future<void> unload() async {
    try {
      if (_controller != null) {
        await _controller.dispose();
      }
    } catch (_) {}
    _controller = null;
    _loadedPath = null;
  }

  Future<String> complete({
    required String prompt,
    int maxTokens = 512,
    double temperature = 0.4,
  }) async {
    if (_controller == null) {
      throw StateError(_lastError ?? 'Model not loaded');
    }
    final buf = StringBuffer();
    final stream = _controller.generate(
      prompt: prompt,
      maxTokens: maxTokens.clamp(64, 2048),
      temperature: temperature,
      topP: 0.9,
      repeatPenalty: 1.1,
    ) as Stream<String>;
    await for (final token in stream) {
      buf.write(token);
    }
    return buf.toString().trim();
  }
}
