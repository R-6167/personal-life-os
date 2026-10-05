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
  bool _loading = true;

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
      _loading = false;
    });
  }

  Future<void> _save() async {
    await AiSettingsStore.instance.save(AiSettings(
      mode: _mode,
      baseUrl: _baseUrl.text.trim(),
      apiKey: _apiKey.text.trim(),
      model: _model.text.trim().isEmpty ? 'gpt-4o-mini' : _model.text.trim(),
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI settings saved on device')),
    );
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
                          'Local Personal Context is the default and works fully offline. '
                          'Remote uses an OpenAI-compatible API and needs network access '
                          '(add INTERNET permission for production remote use).',
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
                              child: Text('Local only (offline)'),
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
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _save,
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
