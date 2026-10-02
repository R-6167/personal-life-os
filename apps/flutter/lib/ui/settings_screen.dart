import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database.dart';
import '../data/export_service.dart';
import '../domain/enums.dart';
import '../services/notification_service.dart';
import 'theme.dart';
import 'widgets/glass.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _name = 'Me';
  String _currency = Defaults.currency;
  int _weekStart = Defaults.weekStartDay;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('users', limit: 1);
    if (rows.isNotEmpty) {
      setState(() {
        _name = (rows.first['display_name'] as String?) ??
            (rows.first['name'] as String?) ??
            'Me';
        _currency = (rows.first['currency'] as String?) ?? Defaults.currency;
        _weekStart = (rows.first['week_start_day'] as int?) ?? Defaults.weekStartDay;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile({String? name, String? currency, int? weekStart}) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('users', limit: 1);
    if (rows.isEmpty) return;
    final id = rows.first['id'] as String;
    await db.update(
      'users',
      {
        if (name != null) 'display_name': name,
        if (currency != null) 'currency': currency,
        if (weekStart != null) 'week_start_day': weekStart,
        'updated_at': AppDatabase.nowMs(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved offline')),
      );
    }
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
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Settings')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SwitchListTile(
                    title: const Text('Local notifications', style: TextStyle(color: AppTheme.silver)),
                    subtitle: Text(
                      'Reminders, bills, overdue nudges',
                      style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12),
                    ),
                    value: NotificationService.instance.enabled,
                    activeColor: AppTheme.amber,
                    onChanged: (v) async {
                      NotificationService.instance.enabled = v;
                      try {
                        if (v) {
                          await NotificationService.instance.init();
                          final n = await NotificationService.instance.syncFromDatabase();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Scheduled $n notifications')),
                            );
                          }
                        } else {
                          await NotificationService.instance.cancelAll();
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Notifications: $e')),
                          );
                        }
                      }
                      setState(() {});
                    },
                  ),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Profile', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Display name', style: TextStyle(color: Colors.white70)),
                          subtitle: Text(_name, style: const TextStyle(color: Colors.white)),
                          trailing: const Icon(Icons.edit, color: Colors.white54, size: 18),
                          onTap: () async {
                            final c = TextEditingController(text: _name);
                            final ok = await showDialog<String>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Display name'),
                                content: TextField(controller: c, autofocus: true),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, c.text.trim()),
                                    child: const Text('Save'),
                                  ),
                                ],
                              ),
                            );
                            if (ok != null && ok.isNotEmpty) await _saveProfile(name: ok);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Preferences', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Currency', style: TextStyle(color: Colors.white70)),
                          subtitle: Text(_currency, style: const TextStyle(color: Colors.white)),
                          onTap: () async {
                            final next = await showDialog<String>(
                              context: context,
                              builder: (ctx) => SimpleDialog(
                                title: const Text('Currency'),
                                children: [
                                  for (final c in ['KES', 'USD', 'EUR', 'GBP', 'UGX', 'TZS'])
                                    SimpleDialogOption(
                                      onPressed: () => Navigator.pop(ctx, c),
                                      child: Text(c),
                                    ),
                                ],
                              ),
                            );
                            if (next != null) await _saveProfile(currency: next);
                          },
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Week starts', style: TextStyle(color: Colors.white70)),
                          subtitle: Text(
                            _weekStart == 0 ? 'Sunday' : 'Monday',
                            style: const TextStyle(color: Colors.white),
                          ),
                          onTap: () async {
                            final next = await showDialog<int>(
                              context: context,
                              builder: (ctx) => SimpleDialog(
                                title: const Text('Week starts on'),
                                children: [
                                  SimpleDialogOption(
                                    onPressed: () => Navigator.pop(ctx, 1),
                                    child: const Text('Monday'),
                                  ),
                                  SimpleDialogOption(
                                    onPressed: () => Navigator.pop(ctx, 0),
                                    child: const Text('Sunday'),
                                  ),
                                ],
                              ),
                            );
                            if (next != null) await _saveProfile(weekStart: next);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Data', style: Theme.of(context).textTheme.titleMedium),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.ios_share, color: AppTheme.seed),
                          title: const Text('Export backup JSON'),
                          subtitle: const Text('Contract-shaped, offline share', style: TextStyle(fontSize: 12, color: Colors.white54)),
                          onTap: _export,
                        ),
                        const ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.storage_outlined, color: Colors.white54),
                          title: Text('Storage'),
                          subtitle: Text('On-device SQLite only', style: TextStyle(fontSize: 12, color: Colors.white54)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('About', style: Theme.of(context).textTheme.titleMedium),
                        const ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Personal Life OS'),
                          subtitle: Text(
                            'Offline client · Material 3 glass · local intelligence\nSchema v5 · contract-first with TypeScript',
                            style: TextStyle(fontSize: 12, color: Colors.white54),
                          ),
                        ),
                        const ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Version'),
                          subtitle: Text('0.6.0'),
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
