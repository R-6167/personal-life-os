import 'package:flutter/material.dart';

import '../data/database.dart';
import '../domain/enums.dart';
import '../services/backup_io.dart';
import '../services/data_management.dart';
import '../services/notification_service.dart';
import '../services/security_service.dart';
import '../services/user_prefs.dart';
import 'app_meta.dart';
import 'screens/ai_settings_screen.dart';
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
  bool _busy = false;

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
    UserPrefs.instance.applyLocal(currency: currency, weekStartDay: weekStart, displayName: name);
    await UserPrefs.instance.load();
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
        title: const Text('Set PIN'),
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
              helperText: 'You will need this to restore',
            ),
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
  }

  Future<void> _wipe() async {
    final typed = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('Wipe all local data?', style: TextStyle(color: Colors.redAccent)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This permanently deletes your offline database and PIN on this device. Export a backup first.',
              style: TextStyle(color: AppTheme.silver),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: typed,
              style: const TextStyle(color: AppTheme.silver),
              decoration: const InputDecoration(labelText: 'Type WIPE to confirm'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              if (typed.text.trim().toUpperCase() != 'WIPE') return;
              Navigator.pop(ctx, true);
            },
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
                  if (_busy) const LinearProgressIndicator(color: AppTheme.amber),
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
                          'Everything stays on this device. No accounts, no cloud sync.',
                          style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.55), fontSize: 13),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Hide balances in UI', style: TextStyle(color: AppTheme.silver)),
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
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Display name'),
                          subtitle: Text(_name),
                          trailing: const Icon(Icons.edit, size: 18),
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
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Currency'),
                          subtitle: Text(_currency),
                          onTap: () async {
                            final next = await showDialog<String>(
                              context: context,
                              builder: (ctx) => SimpleDialog(
                                title: const Text('Currency'),
                                children: [
                                  for (final c in [
                                    'KES', 'USD', 'EUR', 'GBP', 'UGX', 'TZS',
                                    'NGN', 'GHS', 'ZAR', 'INR', 'CAD', 'AUD',
                                  ])
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
                          title: const Text('Week starts on'),
                          subtitle: Text(_weekStart == 1 ? 'Monday' : 'Sunday'),
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
                          leading: const Icon(Icons.folder_open, color: AppTheme.seed),
                          title: const Text('Export backup to file'),
                          onTap: _busy ? null : () => _export(encrypted: false),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.lock, color: AppTheme.amber),
                          title: const Text('Export encrypted backup'),
                          onTap: _busy ? null : () => _export(encrypted: true),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.file_download_outlined, color: AppTheme.silver),
                          title: const Text('Import backup from file'),
                          onTap: _busy ? null : _import,
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                          title: const Text('Wipe all local data',
                              style: TextStyle(color: Colors.redAccent)),
                          onTap: _wipe,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.auto_awesome, color: AppTheme.amber),
                          title: const Text('AI integration', style: TextStyle(color: AppTheme.silver)),
                          subtitle: Text(
                            'Local context · optional remote model',
                            style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right, color: AppTheme.silver),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
                            );
                          },
                        ),
                        Text('About', style: Theme.of(context).textTheme.titleMedium),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Personal Life OS'),
                          subtitle: Text(
                            '${AppMeta.tagline}\nHardened offline SQLite · file backup',
                            style: const TextStyle(fontSize: 12, color: Colors.white54),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
      ),
    );
  }
}
