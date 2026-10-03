import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/extended_repository.dart';
import '../../services/backup_io.dart';
import '../../services/integrity_service.dart';
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
            decoration: const InputDecoration(labelText: 'Passphrase (min 6 chars)'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Encrypt')),
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
    final result = await io.importFromFile();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    await widget.onChanged?.call();
  }

  Future<void> _integrity() async {
    final report = await IntegrityService().run(repair: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(report.summary)));
  }

  @override
  Widget build(BuildContext context) {
    // AppBar already shows "More" — no second page title.
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        TextField(
          controller: _search,
          style: const TextStyle(color: AppTheme.silver),
          decoration: InputDecoration(
            hintText: 'Search tasks, notes, people…',
            hintStyle: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)),
            prefixIcon: const Icon(Icons.search, color: AppTheme.silverMuted),
            filled: true,
            fillColor: AppTheme.metalDeep,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          onChanged: (q) {
            if (q.trim().length >= 2) {
              _runSearch(q);
            } else {
              setState(() => _hits = []);
            }
          },
        ),
        if (_hits.isNotEmpty) ...[
          const SizedBox(height: 8),
          ..._hits.map((h) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: GlassCard(
                  child: ListTile(
                    dense: true,
                    title: Text('${h['label']}', style: const TextStyle(color: AppTheme.silver)),
                    subtitle: Text('${h['kind']}', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11)),
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
        ListTile(
          title: const Text('Ordin', style: TextStyle(color: AppTheme.silver, fontWeight: FontWeight.w600)),
          subtitle: Text(
            'Offline · on-device · com.aetherion.ordin',
            style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12),
          ),
        ),
      ],
    );
  }
}
