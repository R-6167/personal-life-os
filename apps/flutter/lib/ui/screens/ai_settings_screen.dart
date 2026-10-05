import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../services/ai/ai.dart';
import '../theme.dart';
import '../widgets/glass.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  AiMode _mode = AiMode.localOnly;
  final _baseUrl = TextEditingController();
  final _apiKey = TextEditingController();
  final _model = TextEditingController(text: 'gpt-4o-mini');
  String _localPath = '';
  String _localLabel = '';
  bool _loading = true;
  bool _loadingModel = false;
  String? _engineStatus;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _apiKey.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final s = await AiSettingsStore.instance.load();
    if (!mounted) return;
    setState(() {
      _mode = s.mode;
      _baseUrl.text = s.baseUrl;
      _apiKey.text = s.apiKey;
      _model.text = s.model;
      _localPath = s.localModelPath;
      _localLabel = s.localModelLabel;
      _loading = false;
      _engineStatus = LocalLlmEngine.instance.isSupported
          ? (LocalLlmEngine.instance.isLoaded
              ? 'Model loaded in memory'
              : 'Ready — pick a .gguf file')
          : 'On-device GGUF needs Android/iOS';
    });
  }

  Future<void> _save() async {
    await AiSettingsStore.instance.save(AiSettings(
      mode: _mode,
      baseUrl: _baseUrl.text.trim(),
      apiKey: _apiKey.text.trim(),
      model: _model.text.trim().isEmpty ? 'gpt-4o-mini' : _model.text.trim(),
      localModelPath: _localPath,
      localModelLabel: _localLabel,
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI settings saved on device')),
    );
  }

  Future<void> _pickGguf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.single;
    final path = f.path;
    if (path == null || path.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not resolve file path')),
        );
      }
      return;
    }
    if (!path.toLowerCase().endsWith('.gguf')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a .gguf model file')),
        );
      }
      return;
    }
    setState(() {
      _localPath = path;
      _localLabel = f.name.isNotEmpty ? f.name : p.basename(path);
    });
  }

  Future<void> _preload() async {
    if (_localPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a .gguf file first')),
      );
      return;
    }
    setState(() {
      _loadingModel = true;
      _engineStatus = 'Loading model into memory…';
    });
    await _save();
    final settings = await AiSettingsStore.instance.load();
    final ok = await LocalLlmEngine.instance.ensureLoaded(settings);
    if (!mounted) return;
    setState(() {
      _loadingModel = false;
      _engineStatus = ok
          ? 'Loaded: $_localLabel'
          : (LocalLlmEngine.instance.lastError ?? 'Load failed');
    });
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('AI integration')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personal Context is always built first and injected as ground truth.\n\n'
                          '• Rule engine — offline, no model file\n'
                          '• On-device GGUF — llama.cpp on this phone (private)\n'
                          '• Remote — optional OpenAI-compatible API',
                          style: TextStyle(
                            color: AppTheme.silver.withValues(alpha: 0.55),
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<AiMode>(
                          value: _mode,
                          dropdownColor: AppTheme.metal,
                          decoration: const InputDecoration(labelText: 'Mode'),
                          items: const [
                            DropdownMenuItem(
                              value: AiMode.localOnly,
                              child: Text('Rule engine only'),
                            ),
                            DropdownMenuItem(
                              value: AiMode.onDeviceLlm,
                              child: Text('On-device GGUF'),
                            ),
                            DropdownMenuItem(
                              value: AiMode.onDeviceWithFallback,
                              child: Text('On-device + rule fallback'),
                            ),
                            DropdownMenuItem(
                              value: AiMode.remoteWithFallback,
                              child: Text('Remote + local fallback'),
                            ),
                            DropdownMenuItem(
                              value: AiMode.remoteOnly,
                              child: Text('Remote only'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _mode = v);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('On-device model (GGUF)',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          _localLabel.isEmpty
                              ? 'No model selected'
                              : _localLabel,
                          style: const TextStyle(color: AppTheme.silver),
                        ),
                        if (_localPath.isNotEmpty)
                          Text(
                            _localPath,
                            style: TextStyle(
                              color: AppTheme.silver.withValues(alpha: 0.4),
                              fontSize: 11,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (_engineStatus != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _engineStatus!,
                            style: TextStyle(
                              color: AppTheme.amber.withValues(alpha: 0.85),
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            FilledButton.tonal(
                              onPressed: _pickGguf,
                              child: const Text('Pick .gguf'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonal(
                              onPressed: _loadingModel ? null : _preload,
                              child: _loadingModel
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Text('Load model'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tip: use a small quant (Q4_K_M) such as Phi-3 mini, '
                          'Gemma 2B, or Qwen 1.5–3B for phones.',
                          style: TextStyle(
                            color: AppTheme.silver.withValues(alpha: 0.45),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Remote API (optional)',
                            style: Theme.of(context).textTheme.titleMedium),
                        TextField(
                          controller: _baseUrl,
                          style: const TextStyle(color: AppTheme.silver),
                          decoration: const InputDecoration(
                            labelText: 'API base URL',
                            hintText: 'https://api.openai.com/v1',
                          ),
                        ),
                        TextField(
                          controller: _apiKey,
                          obscureText: true,
                          style: const TextStyle(color: AppTheme.silver),
                          decoration:
                              const InputDecoration(labelText: 'API key'),
                        ),
                        TextField(
                          controller: _model,
                          style: const TextStyle(color: AppTheme.silver),
                          decoration: const InputDecoration(labelText: 'Model'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _save,
                    child: const Text('Save AI settings'),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
      ),
    );
  }
}
