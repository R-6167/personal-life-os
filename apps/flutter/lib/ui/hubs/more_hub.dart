import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/database.dart';
import '../../data/export_service.dart';
import '../../data/extended_repository.dart';
import '../../services/integrity_service.dart';
import '../../services/secure_backup.dart';
import '../screens/activity_screen.dart';
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

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String q) async {
    final hits = await ExtendedRepository(AppDatabase.instance).search(q);
    setState(() => _hits = hits);
  }

  Future<void> _export() async {
    final json = await ExportService(AppDatabase.instance).buildBackupJson();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/personal-life-os-backup.json');
    await file.writeAsString(json);
    await Share.shareXFiles([XFile(file.path)], text: 'Personal Life OS backup');
  }

  Future<void> _import() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('Import backup', style: TextStyle(color: AppTheme.silver)),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: ctrl,
            maxLines: 10,
            style: const TextStyle(color: AppTheme.silver, fontSize: 12, fontFamily: 'monospace'),
            decoration: const InputDecoration(
              hintText: 'Paste backup JSON (plain or encrypted)',
              alignLabelWithHint: true,
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    var raw = ctrl.text.trim();
    if (SecureBackup.looksEncrypted(raw)) {
      final pass = TextEditingController();
      final unlocked = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.metal,
          title: const Text('Encrypted backup', style: TextStyle(color: AppTheme.silver)),
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
      if (unlocked != true) return;
      try {
        raw = SecureBackup.decrypt(raw, pass.text);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
        return;
      }
    }
    final result = await ExportService(AppDatabase.instance).importBackupJson(raw);
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: Text(
          result.ok ? 'Import result' : 'Import failed',
          style: const TextStyle(color: AppTheme.silver),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result.message, style: const TextStyle(color: AppTheme.silver)),
              if (result.inserted.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Tables updated',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5), fontSize: 12),
                ),
                const SizedBox(height: 6),
                ...result.inserted.entries.map(
                  (e) => Text(
                    '• ${e.key}: ${e.value}',
                    style: const TextStyle(color: AppTheme.amber, fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
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
        title: Text(
          report.ok ? 'Integrity OK' : 'Integrity issues',
          style: const TextStyle(color: AppTheme.silver),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (report.fixed > 0)
                  Text(
                    'Repaired ${report.fixed} issue(s)',
                    style: const TextStyle(color: AppTheme.amber),
                  ),
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
          'Search · timeline · upcoming · backup · integrity',
          style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12),
        ),
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
              subtitle: Text(h['type'] ?? '', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11)),
            )),
        const SizedBox(height: 20),
        GlassCard(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.history, color: AppTheme.amber),
                title: const Text('Activity timeline', style: TextStyle(color: AppTheme.silver)),
                subtitle: Text(
                  'Human-readable life events',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 12),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ActivityScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.upcoming, color: AppTheme.amber),
                title: const Text('Upcoming', style: TextStyle(color: AppTheme.silver)),
                subtitle: Text(
                  'Tasks · bills · habits · appointments',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 12),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const UpcomingScreen()),
                  );
                },
              ),
              const Divider(color: Colors.white12),
              ListTile(
                leading: const Icon(Icons.ios_share, color: AppTheme.amber),
                title: const Text('Export backup', style: TextStyle(color: AppTheme.silver)),
                subtitle: Text(
                  'JSON copy of offline data',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 12),
                ),
                onTap: _export,
              ),
              ListTile(
                leading: const Icon(Icons.file_download_outlined, color: AppTheme.silver),
                title: const Text('Import backup', style: TextStyle(color: AppTheme.silver)),
                subtitle: Text(
                  'Plain or encrypted · verified merge',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 12),
                ),
                onTap: _import,
              ),
              ListTile(
                leading: const Icon(Icons.health_and_safety_outlined, color: AppTheme.silver),
                title: const Text('Data integrity check', style: TextStyle(color: AppTheme.silver)),
                subtitle: Text(
                  'Dedupe · link checks · repair',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 12),
                ),
                onTap: _integrity,
              ),
              const Divider(color: Colors.white12),
              ListTile(
                leading: const Icon(Icons.settings_outlined, color: AppTheme.silver),
                title: const Text('Settings', style: TextStyle(color: AppTheme.silver)),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline, color: AppTheme.silver),
                title: const Text('About', style: TextStyle(color: AppTheme.silver)),
                subtitle: Text(
                  'Personal Life OS · offline · schema v${AppDatabase.schemaVersion} · 0.12',
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
