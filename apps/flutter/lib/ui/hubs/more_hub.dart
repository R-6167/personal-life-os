import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/extended_repository.dart';
import '../../services/backup_io.dart';
import '../../services/integrity_service.dart';
import '../screens/activity_screen.dart';
import '../screens/diagnostics_screen.dart';
import '../screens/feedback_screen.dart';
import '../screens/offline_status_screen.dart';
import '../screens/reminders_screen.dart';
import '../screens/upcoming_screen.dart';
import '../settings_screen.dart';
import '../theme.dart';
import '../widgets/glass.dart';

class MoreHub extends StatefulWidget {
  const MoreHub({super.key, required this.onChanged});

  final Future<void> Function() onChanged;

  @override
  State<MoreHub> createState() => _MoreHubState();
}

class _MoreHubState extends State<MoreHub> {
  final _search = TextEditingController();
  List<Map<String, String>> _hits = [];
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String q) async {
    final hits = await ExtendedRepository(AppDatabase.instance).search(q);
    setState(() => _hits = hits);
  }

  Future<void> _export({bool encrypted = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    String? passphrase;
    if (encrypted) {
      final pass = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.metal,
          title: const Text('Encrypt backup'),
          content: TextField(
            controller: pass,
            obscureText: true,
            style: const TextStyle(color: AppTheme.silver),
            decoration: const InputDecoration(
              labelText: 'Passphrase (min 6 chars)',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
          ],
        ),
      );
      if (ok != true) {
        setState(() => _busy = false);
        return;
      }
      passphrase = pass.text;
    }
    final result = await BackupIo(AppDatabase.instance).exportToFile(
      encrypted: encrypted,
      passphrase: passphrase,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _import() async {
    if (_busy) return;
    setState(() => _busy = true);
    final io = BackupIo(AppDatabase.instance);
    var result = await io.importFromFile();

    if (result.needsPassphrase && result.pendingRaw != null) {
      final pass = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.metal,
          title: const Text('Encrypted backup'),
          content: TextField(
            controller: pass,
            obscureText: true,
            style: const TextStyle(color: AppTheme.silver),
            decoration: const InputDecoration(labelText: 'Passphrase'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Decrypt')),
          ],
        ),
      );
      if (ok == true) {
        result = await io.importEncryptedRaw(result.pendingRaw!, pass.text);
      } else {
        result = BackupIoResult(ok: false, message: 'Import cancelled');
      }
    }

    if (!mounted) return;
    setState(() => _busy = false);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: Text(result.ok ? 'Import result' : 'Import failed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(result.message, style: const TextStyle(color: AppTheme.silver)),
            if (result.inserted.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...result.inserted.entries.map(
                (e) => Text('• ${e.key}: ${e.value}',
                    style: const TextStyle(color: AppTheme.amber, fontSize: 13)),
              ),
            ],
          ],
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
    if (result.ok) await widget.onChanged();
  }

  Future<void> _integrity() async {
    final report = await IntegrityService().run(repair: true);
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: Text(report.ok ? 'Integrity OK' : 'Integrity issues'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (report.fixed > 0)
                Text('Repaired ${report.fixed} issue(s)',
                    style: const TextStyle(color: AppTheme.amber)),
              const SizedBox(height: 8),
              ...report.checks.map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(c, style: const TextStyle(color: AppTheme.silver, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
    await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        const Text('More', style: TextStyle(color: AppTheme.silver, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          'Search · reminders · offline · backup · integrity',
          style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12),
        ),
        if (_busy) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(color: AppTheme.amber),
        ],
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  style: const TextStyle(color: AppTheme.silver),
                  decoration: const InputDecoration(
                    hintText: 'Search tasks, bills, people…',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                  onSubmitted: _runSearch,
                ),
              ),
              IconButton(
                onPressed: () => _runSearch(_search.text),
                icon: const Icon(Icons.search, color: AppTheme.amber),
              ),
            ],
          ),
        ),
        ..._hits.map((h) => ListTile(
              dense: true,
              title: Text(h['title'] ?? '', style: const TextStyle(color: AppTheme.silver)),
              subtitle: Text(h['type'] ?? '',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11)),
            )),
        const SizedBox(height: 20),
        GlassCard(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.history, color: AppTheme.amber),
                title: const Text('Activity timeline', style: TextStyle(color: AppTheme.silver)),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ActivityScreen()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.alarm, color: AppTheme.amber),
                title: const Text('Reminders', style: TextStyle(color: AppTheme.silver)),
                subtitle: Text(
                  'Create · snooze · complete',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 12),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RemindersScreen()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.upcoming, color: AppTheme.amber),
                title: const Text('Upcoming', style: TextStyle(color: AppTheme.silver)),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const UpcomingScreen()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.bug_report_outlined, color: AppTheme.amber),
                title: const Text('Feedback & bugs', style: TextStyle(color: AppTheme.silver)),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FeedbackScreen()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.cloud_off_outlined, color: AppTheme.amber),
                title: const Text('Offline status', style: TextStyle(color: AppTheme.silver)),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const OfflineStatusScreen()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.analytics_outlined, color: AppTheme.silver),
                title: const Text('Diagnostics', style: TextStyle(color: AppTheme.silver)),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DiagnosticsScreen()),
                ),
              ),
              const Divider(color: Colors.white12),
              ListTile(
                leading: const Icon(Icons.folder_open, color: AppTheme.amber),
                title: const Text('Export backup to file', style: TextStyle(color: AppTheme.silver)),
                subtitle: Text(
                  'Save JSON via file picker',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 12),
                ),
                onTap: _busy ? null : () => _export(encrypted: false),
              ),
              ListTile(
                leading: const Icon(Icons.lock, color: AppTheme.amber),
                title: const Text('Export encrypted backup', style: TextStyle(color: AppTheme.silver)),
                onTap: _busy ? null : () => _export(encrypted: true),
              ),
              ListTile(
                leading: const Icon(Icons.file_download_outlined, color: AppTheme.silver),
                title: const Text('Import backup from file', style: TextStyle(color: AppTheme.silver)),
                onTap: _busy ? null : _import,
              ),
              ListTile(
                leading: const Icon(Icons.health_and_safety_outlined, color: AppTheme.silver),
                title: const Text('Data integrity check', style: TextStyle(color: AppTheme.silver)),
                onTap: _integrity,
              ),
              const Divider(color: Colors.white12),
              ListTile(
                leading: const Icon(Icons.settings_outlined, color: AppTheme.silver),
                title: const Text('Settings', style: TextStyle(color: AppTheme.silver)),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline, color: AppTheme.silver),
                title: const Text('About', style: TextStyle(color: AppTheme.silver)),
                subtitle: Text(
                  'Personal Life OS · offline · schema v${AppDatabase.schemaVersion} · 0.18',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
