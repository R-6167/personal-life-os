import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database.dart';
import '../data/export_service.dart';
import '../domain/enums.dart';
import '../services/data_management.dart';
import '../services/notification_service.dart';
import '../services/secure_backup.dart';
import '../services/security_service.dart';
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
  bool _lockEnabled = false;
  bool _hideBalances = false;
  int _autoLock = 5;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await SecurityService.instance.load();
    final db = await AppDatabase.instance.database;
    final rows = await db.query('users', limit: 1);
    if (rows.isNotEmpty) {
      setState(() {
        _name = (rows.first['display_name'] as String?) ??
            (rows.first['name'] as String?) ??
            'Me';
        _currency = (rows.first['currency'] as String?) ?? Defaults.currency;
        _weekStart = (rows.first['week_start_day'] as int?) ?? Defaults.weekStartDay;
        _lockEnabled = SecurityService.instance.lockEnabled;
        _hideBalances = SecurityService.instance.hideBalances;
        _autoLock = SecurityService.instance.autoLockMinutes;
        _loading = false;
      });
    } else {
      setState(() {
        _lockEnabled = SecurityService.instance.lockEnabled;
        _hideBalances = SecurityService.instance.hideBalances;
        _autoLock = SecurityService.instance.autoLockMinutes;
        _loading = false;
      });
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

  Future<void> _setPin() async {
    final a = TextEditingController();
    final b = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('Set PIN', style: TextStyle(color: AppTheme.silver)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: a,
              obscureText: true,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppTheme.silver),
              decoration: const InputDecoration(labelText: 'PIN (4–12 digits)'),
            ),
            TextField(
              controller: b,
              obscureText: true,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppTheme.silver),
              decoration: const InputDecoration(labelText: 'Confirm PIN'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (a.text != b.text) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SecurityService.instance.setPin(a.text.trim());
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN set — lock enabled')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _export({bool encrypted = false}) async {
    var json = await ExportService(AppDatabase.instance).buildBackupJson();
    if (encrypted) {
      final pass = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.metal,
          title: const Text('Encrypt backup', style: TextStyle(color: AppTheme.silver)),
          content: TextField(
            controller: pass,
            obscureText: true,
            style: const TextStyle(color: AppTheme.silver),
            decoration: const InputDecoration(
              labelText: 'Passphrase (min 6 chars)',
              helperText: 'You will need this to restore',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Encrypt')),
          ],
        ),
      );
      if (ok != true) return;
      try {
        json = SecureBackup.encrypt(json, pass.text);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
        }
        return;
      }
    }
    final dir = await getTemporaryDirectory();
    final name = encrypted ? 'personal-life-os-backup.enc.json' : 'personal-life-os-backup.json';
    final file = File('${dir.path}/$name');
    await file.writeAsString(json);
    await Share.shareXFiles([XFile(file.path)], text: 'Personal Life OS backup');
  }

  Future<void> _wipe() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('Wipe all local data?', style: TextStyle(color: Colors.redAccent)),
        content: const Text(
          'This permanently deletes your offline database and PIN on this device. Export a backup first if you need it.',
          style: TextStyle(color: AppTheme.silver),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Wipe'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await DataManagement.wipeAllLocalData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Local data wiped. Restart the app.')),
    );
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
                      'Reminders, bills, budgets, overdue',
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
                        Text('Security', style: Theme.of(context).textTheme.titleMedium),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('App lock', style: TextStyle(color: AppTheme.silver)),
                          subtitle: Text(
                            SecurityService.instance.hasPin
                                ? 'PIN required on open'
                                : 'Set a PIN first',
                            style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12),
                          ),
                          value: _lockEnabled && SecurityService.instance.hasPin,
                          activeColor: AppTheme.amber,
                          onChanged: (v) async {
                            try {
                              if (v && !SecurityService.instance.hasPin) {
                                await _setPin();
                                return;
                              }
                              await SecurityService.instance.setLockEnabled(v);
                              await _load();
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                              }
                            }
                          },
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Set / change PIN', style: TextStyle(color: AppTheme.silver)),
                          trailing: const Icon(Icons.pin, color: AppTheme.amber),
                          onTap: _setPin,
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Auto-lock', style: TextStyle(color: AppTheme.silver)),
                          subtitle: Text(
                            _autoLock == 0 ? 'Only when app is killed' : 'After $_autoLock min in background',
                            style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12),
                          ),
                          onTap: () async {
                            final next = await showDialog<int>(
                              context: context,
                              builder: (ctx) => SimpleDialog(
                                title: const Text('Auto-lock after'),
                                children: [
                                  for (final m in [0, 1, 5, 15, 30])
                                    SimpleDialogOption(
                                      onPressed: () => Navigator.pop(ctx, m),
                                      child: Text(m == 0 ? 'Off (cold start only)' : '$m minutes'),
                                    ),
                                ],
                              ),
                            );
                            if (next != null) {
                              await SecurityService.instance.setAutoLockMinutes(next);
                              await _load();
                            }
                          },
                        ),
                        if (SecurityService.instance.hasPin)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Remove PIN', style: TextStyle(color: Colors.redAccent)),
                            onTap: () async {
                              await SecurityService.instance.clearPin();
                              await _load();
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
                        Text('Privacy', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          'Everything stays on this device. No accounts, no cloud sync, no analytics in this client.',
                          style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.55), fontSize: 13),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Hide balances in UI', style: TextStyle(color: AppTheme.silver)),
                          subtitle: Text(
                            'Mask amounts until you turn this off',
                            style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12),
                          ),
                          value: _hideBalances,
                          activeColor: AppTheme.amber,
                          onChanged: (v) async {
                            await SecurityService.instance.setHideBalances(v);
                            await _load();
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
                        Text('Data management', style: Theme.of(context).textTheme.titleMedium),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.ios_share, color: AppTheme.seed),
                          title: const Text('Export backup JSON'),
                          subtitle: const Text('Plain offline share', style: TextStyle(fontSize: 12, color: Colors.white54)),
                          onTap: () => _export(encrypted: false),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.lock, color: AppTheme.amber),
                          title: const Text('Export encrypted backup'),
                          subtitle: const Text('AES + passphrase', style: TextStyle(fontSize: 12, color: Colors.white54)),
                          onTap: () => _export(encrypted: true),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                          title: const Text('Wipe all local data', style: TextStyle(color: Colors.redAccent)),
                          subtitle: const Text('Deletes DB + PIN on this device', style: TextStyle(fontSize: 12, color: Colors.white54)),
                          onTap: _wipe,
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
                            'Offline · local-first · no cloud account\nSchema-backed SQLite · optional PIN lock',
                            style: TextStyle(fontSize: 12, color: Colors.white54),
                          ),
                        ),
                        const ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Version'),
                          subtitle: Text('0.12.0'),
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
