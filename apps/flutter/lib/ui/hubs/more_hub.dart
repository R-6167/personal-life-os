import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/extended_repository.dart';
import '../../services/backup_io.dart';
import '../../services/integrity_service.dart';
import '../screens/activity_screen.dart';
import '../screens/reminders_screen.dart';
import '../settings_screen.dart';
import '../theme.dart';
import '../widgets/glass.dart';

class MoreHub extends StatefulWidget {
  const MoreHub({super.key, this.onChanged});

  final Future<void> Function()? onChanged;

  @override
  State<MoreHub> createState() => _MoreHubState();
}

class _MoreHubState extends State<MoreHub> {
  final _search = TextEditingController();
  List<Map<String, Object?>> _hits = [];
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String q) async {
    if (q.trim().length < 2) {
      setState(() => _hits = []);
      return;
    }
    final hits = await ExtendedRepository(AppDatabase.instance).search(q.trim());
    if (!mounted) return;
    setState(() => _hits = hits);
  }

  Future<void> _export({bool encrypted = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    String? passphrase;
    if (encrypted) {
      final ctrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.metal,
          title: const Text('Encrypt backup'),
          content: TextField(
            controller: ctrl,
            obscureText: true,
            style: const TextStyle(color: AppTheme.silver),
            decoration: const InputDecoration(labelText: 'Passphrase'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Encrypt')),
          ],
        ),
      );
      if (ok != true || ctrl.text.isEmpty) {
        setState(() => _busy = false);
        return;
      }
      passphrase = ctrl.text;
    }
    final result = await BackupIo(AppDatabase.instance).exportToFile(
      encrypted: encrypted,
      passphrase: passphrase,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.ok ? (result.message ?? 'Exported') : (result.message ?? 'Export failed'))),
    );
  }

  Future<void> _import() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await BackupIo(AppDatabase.instance).importFromFile();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.ok ? (result.message ?? 'Import complete') : (result.message ?? 'Import failed'))),
    );
    if (result.ok) await widget.onChanged?.call();
  }

  Future<void> _integrity() async {
    if (_busy) return;
    setState(() => _busy = true);
    final report = await IntegrityService().run(repair: true);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(report.summary)));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        TextField(
          controller: _search,
          style: const TextStyle(color: AppTheme.silver),
          decoration: const InputDecoration(
            labelText: 'Search',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: _runSearch,
        ),
        if (_hits.isNotEmpty) ...[
          const SizedBox(height: 12),
          ..._hits.map((h) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: GlassCard(
                  child: ListTile(
                    title: Text('${h['label'] ?? h['title'] ?? h['name']}',
                        style: const TextStyle(color: AppTheme.silver)),
                    subtitle: Text('${h['kind'] ?? h['_table'] ?? ''}',
                        style: TextStyle(
                            color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11)),
                  ),
                ),
              )),
        ],
        const SizedBox(height: 12),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.auto_stories_outlined, color: AppTheme.amber),
                title: const Text('Your Life Timeline', style: TextStyle(color: AppTheme.silver)),
                subtitle: Text(
                  'What you did — personal history',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppTheme.silverMuted),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ActivityScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.alarm, color: AppTheme.amber),
                title: const Text('Reminders', style: TextStyle(color: AppTheme.silver)),
                trailing: const Icon(Icons.chevron_right, color: AppTheme.silverMuted),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RemindersScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined, color: AppTheme.amber),
                title: const Text('Settings', style: TextStyle(color: AppTheme.silver)),
                trailing: const Icon(Icons.chevron_right, color: AppTheme.silverMuted),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.upload_file, color: AppTheme.amber),
                title: const Text('Export backup', style: TextStyle(color: AppTheme.silver)),
                onTap: _busy ? null : () => _export(),
              ),
              ListTile(
                leading: const Icon(Icons.lock_outline, color: AppTheme.amber),
                title: const Text('Export encrypted backup', style: TextStyle(color: AppTheme.silver)),
                onTap: _busy ? null : () => _export(encrypted: true),
              ),
              ListTile(
                leading: const Icon(Icons.download, color: AppTheme.amber),
                title: const Text('Import backup', style: TextStyle(color: AppTheme.silver)),
                onTap: _busy ? null : _import,
              ),
              ListTile(
                leading: const Icon(Icons.health_and_safety_outlined, color: AppTheme.amber),
                title: const Text('Integrity check + repair', style: TextStyle(color: AppTheme.silver)),
                onTap: _busy ? null : _integrity,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Ordin is fully offline. Your data stays on this device.',
          style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 12),
        ),
      ],
    );
  }
}
