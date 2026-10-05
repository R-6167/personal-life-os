import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

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
  String? _sizeLabel;
  bool _loading = true;
  bool _busy = false;
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
      _refreshEngineStatus();
    });
  }

  void _refreshEngineStatus() {
    final eng = LocalLlmEngine.instance;
    if (!eng.isSupported) {
      _engineStatus = 'On-device GGUF needs Android/iOS';
      return;
    }
    switch (eng.status) {
      case LlmEngineStatus.ready:
        _engineStatus = 'Ready: ${eng.loadedLabel ?? _localLabel}';
        break;
      case LlmEngineStatus.loading:
        _engineStatus = 'Loading model…';
        break;
      case LlmEngineStatus.generating:
        _engineStatus = 'Generating…';
        break;
      case LlmEngineStatus.error:
        _engineStatus = eng.lastError ?? 'Error';
        break;
      case LlmEngineStatus.idle:
        _engineStatus = _localPath.isEmpty
            ? 'Pick a .gguf (copied into app storage)'
            : 'Model path saved — tap Load';
        break;
    }
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
      const SnackBar(content: Text('AI settings saved')),
    );
  }

  Future<void> _pickAndImport() async {
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
      _busy = true;
      _engineStatus = 'Importing into app storage…';
    });
    try {
      final imported = await LocalModelStore.instance.importGguf(
        path,
        preferredName: f.name,
      );
      if (!mounted) return;
      setState(() {
        _localPath = imported.path;
        _localLabel = imported.label;
        _sizeLabel = LocalModelStore.formatBytes(imported.bytes);
        _busy = false;
        _engineStatus = 'Imported $_localLabel ($_sizeLabel)';
      });
      await _save();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _engineStatus = 'Import failed: $e';
      });
    }
  }

  Future<void> _preload() async {
    if (_localPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import a .gguf file first')),
      );
      return;
    }
    setState(() {
      _busy = true;
      _engineStatus = 'Loading into RAM (may take a minute)…';
    });
    await _save();
    final settings = await AiSettingsStore.instance.load();
    final ok = await LocalLlmEngine.instance.ensureLoaded(settings);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _refreshEngineStatus();
      if (!ok) {
        _engineStatus = LocalLlmEngine.instance.lastError ?? 'Load failed';
      }
    });
  }

  Future<void> _unload() async {
    await LocalLlmEngine.instance.unload();
    if (!mounted) return;
    setState(_refreshEngineStatus);
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
                          'Personal Context is always injected first.\n\n'
                          'On-device: import a .gguf, load it, set mode to '
                          'On-device GGUF. Prefer small Q4 models on phones.',
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
                              ? 'No model imported'
                              : _localLabel,
                          style: const TextStyle(color: AppTheme.silver),
                        ),
                        if (_sizeLabel != null)
                          Text(_sizeLabel!,
                              style: TextStyle(
                                  color: AppTheme.silver.withValues(alpha: 0.5),
                                  fontSize: 12)),
                        if (_localPath.isNotEmpty)
                          Text(
                            _localPath,
                            style: TextStyle(
                              color: AppTheme.silver.withValues(alpha: 0.35),
                              fontSize: 10,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (_engineStatus != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _engineStatus!,
                            style: TextStyle(
                              color: AppTheme.amber.withValues(alpha: 0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.tonal(
                              onPressed: _busy ? null : _pickAndImport,
                              child: const Text('Import .gguf'),
                            ),
                            FilledButton.tonal(
                              onPressed: _busy ? null : _preload,
                              child: const Text('Load model'),
                            ),
                            TextButton(
                              onPressed: _busy ? null : _unload,
                              child: const Text('Unload'),
                            ),
                          ],
                        ),
                        if (_busy)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: LinearProgressIndicator(),
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
                    onPressed: _busy ? null : _save,
                    child: const Text('Save AI settings'),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
      ),
    );
  }
}
