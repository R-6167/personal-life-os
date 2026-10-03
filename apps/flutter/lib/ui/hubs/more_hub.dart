import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/extended_repository.dart';
import '../../services/backup_io.dart';
import '../../services/integrity_service.dart';
import '../app_meta.dart';
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.ok) await widget.onChanged?.call();
  }

  Future<void> _integrity() async {
    setState(() => _busy = true);
    final report = await IntegrityService().run(repair: true);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(report.summary)),
    );
    await widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('More')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (_busy) const LinearProgressIndicator(color: AppTheme.amber),
            TextField(
              controller: _search,
              style: const TextStyle(color: AppTheme.silver),
              decoration: const InputDecoration(
                hintText: 'Search tasks, notes, people…',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: _runSearch,
            ),
            ..._hits.map(
              (h) => ListTile(
                dense: true,
                title: Text(
                  h['label']?.toString() ?? h['title']?.toString() ?? '',
                  style: const TextStyle(color: AppTheme.silver),
                ),
                subtitle: Text(
                  h['kind']?.toString() ?? h['type']?.toString() ?? '',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 11),
                ),
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.notifications_active, color: AppTheme.amber),
                    title: const Text('Reminders'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RemindersScreen()),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings, color: AppTheme.silver),
                    title: const Text('Settings'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.folder_open, color: AppTheme.seed),
                    title: const Text('Export backup'),
                    onTap: _busy ? null : () => _export(encrypted: false),
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock, color: AppTheme.amber),
                    title: const Text('Export encrypted backup'),
                    onTap: _busy ? null : () => _export(encrypted: true),
                  ),
                  ListTile(
                    leading: const Icon(Icons.file_download_outlined, color: AppTheme.silver),
                    title: const Text('Import backup'),
                    onTap: _busy ? null : _import,
                  ),
                  ListTile(
                    leading: const Icon(Icons.health_and_safety, color: AppTheme.woodLight),
                    title: const Text('Integrity check + repair'),
                    onTap: _busy ? null : _integrity,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: ListTile(
                title: const Text('Personal Life OS'),
                subtitle: Text(
                  '${AppMeta.tagline}\n${AppMeta.versionLabel}',
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
