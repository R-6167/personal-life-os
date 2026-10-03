import 'package:flutter/material.dart';

import '../../services/offline_runtime.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import '../widgets/offline_badge.dart';

class OfflineStatusScreen extends StatefulWidget {
  const OfflineStatusScreen({super.key});

  @override
  State<OfflineStatusScreen> createState() => _OfflineStatusScreenState();
}

class _OfflineStatusScreenState extends State<OfflineStatusScreen> {
  OfflineHealth? _health;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => _loading = true);
    await OfflineRuntime.instance.runMaintenance(force: true);
    final h = await OfflineRuntime.instance.healthCheck();
    if (!mounted) return;
    setState(() {
      _health = h;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final caps = OfflineRuntime.instance.capabilities;
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Offline status'),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _run),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const Center(child: OfflineBadge(compact: false)),
            const SizedBox(height: 16),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This app never requires the internet',
                    style: TextStyle(
                      color: AppTheme.silver,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tasks, habits, finance, backups, and reminders all run from local SQLite on this device. Sharing a backup is optional and user-initiated.',
                    style: TextStyle(
                      color: AppTheme.silver.withValues(alpha: 0.55),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Capabilities', style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...caps.lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppTheme.amber, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(line, style: const TextStyle(color: AppTheme.silver, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Health check', style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_loading)
              const Center(child: CircularProgressIndicator(color: AppTheme.amber))
            else if (_health != null)
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _health!.ok ? 'All offline systems OK' : 'Issues detected',
                      style: TextStyle(
                        color: _health!.ok ? AppTheme.woodLight : Colors.redAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._health!.checks.map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(c, style: const TextStyle(color: AppTheme.silver, fontSize: 12)),
                      ),
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
