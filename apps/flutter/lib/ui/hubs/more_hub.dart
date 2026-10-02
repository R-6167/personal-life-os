import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/database.dart';
import '../../data/export_service.dart';
import '../../data/extended_repository.dart';
import '../settings_screen.dart';
import '../theme.dart';
import '../widgets/glass.dart';

/// Secondary navigation only — not a domain CRUD dump.
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

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        const Text('More', style: TextStyle(color: AppTheme.silver, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          'Search, data, and settings',
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
                leading: const Icon(Icons.ios_share, color: AppTheme.amber),
                title: const Text('Export backup', style: TextStyle(color: AppTheme.silver)),
                subtitle: Text(
                  'JSON copy of your offline data',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 12),
                ),
                onTap: _export,
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
