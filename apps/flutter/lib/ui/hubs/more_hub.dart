import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/database.dart';
import '../../data/export_service.dart';
import '../../data/extended_repository.dart';
import '../screens/activity_screen.dart';
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
              hintText: 'Paste backup JSON here',
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
    final result = await ExportService(AppDatabase.instance).importBackupJson(ctrl.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.ok) await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        const Text('More', style: TextStyle(color: AppTheme.silver, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          'Search, history, backup, settings',
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
                title: const Text('Activity', style: TextStyle(color: AppTheme.silver)),
                subtitle: Text(
                  'What you did in the OS',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 12),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ActivityScreen()),
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
                  'Paste JSON — merges without wiping',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 12),
                ),
                onTap: _import,
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
                  'Personal Life OS · offline · schema v6',
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
