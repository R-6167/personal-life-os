import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/error_log_service.dart';
import '../../services/local_analytics.dart';
import '../theme.dart';
import '../widgets/glass.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  Map<String, int> _events = {};
  Map<String, int> _screens = {};
  List<Map<String, Object?>> _errors = [];
  int _total = 0;
  int _errorCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final events = await LocalAnalytics.instance.countsByEvent();
    final screens = await LocalAnalytics.instance.countsByScreen();
    final total = await LocalAnalytics.instance.totalEvents();
    final errors = await ErrorLogService.instance.recent(limit: 30);
    final errorCount = await ErrorLogService.instance.count();
    if (!mounted) return;
    setState(() {
      _events = events;
      _screens = screens;
      _total = total;
      _errors = errors;
      _errorCount = errorCount;
      _loading = false;
    });
  }

  Future<void> _shareErrors() async {
    final buf = StringBuffer('Personal Life OS — local error log\n');
    for (final e in _errors) {
      buf.writeln('---');
      buf.writeln('${e['level']}: ${e['message']}');
      if (e['stack'] != null) buf.writeln('${e['stack']}');
    }
    await Share.share(buf.toString(), subject: 'PLOS error log');
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Diagnostics'),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.amber))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Local only — never uploaded',
                          style: TextStyle(color: AppTheme.amber, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$_total usage events · $_errorCount errors (30 days)',
                          style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.55)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Top events', style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (_events.isEmpty)
                    Text('No usage data yet', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4)))
                  else
                    ..._events.entries.take(12).map(
                          (e) => ListTile(
                            dense: true,
                            title: Text(e.key, style: const TextStyle(color: AppTheme.silver)),
                            trailing: Text('${e.value}', style: const TextStyle(color: AppTheme.amber)),
                          ),
                        ),
                  const SizedBox(height: 12),
                  const Text('Screens', style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                  if (_screens.isEmpty)
                    Text('—', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4)))
                  else
                    ..._screens.entries.take(10).map(
                          (e) => ListTile(
                            dense: true,
                            title: Text(e.key, style: const TextStyle(color: AppTheme.silver)),
                            trailing: Text('${e.value}', style: const TextStyle(color: AppTheme.amber)),
                          ),
                        ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Recent errors', style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      if (_errors.isNotEmpty)
                        TextButton(onPressed: _shareErrors, child: const Text('Share log')),
                      TextButton(
                        onPressed: () async {
                          await ErrorLogService.instance.clearAll();
                          await _load();
                        },
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                  if (_errors.isEmpty)
                    Text('No errors logged', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4)))
                  else
                    ..._errors.map((e) {
                      final ms = e['occurred_at'] as int?;
                      final when = ms == null
                          ? ''
                          : DateTime.fromMillisecondsSinceEpoch(ms).toString().substring(0, 16);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${e['level']} · $when',
                                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${e['message']}',
                                style: const TextStyle(color: AppTheme.silver, fontSize: 13),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
      ),
    );
  }
}
