import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/extended_repository.dart';
import '../theme.dart';
import '../widgets/glass.dart';

class PracticalLifeScreen extends StatefulWidget {
  const PracticalLifeScreen({super.key});

  @override
  State<PracticalLifeScreen> createState() => _PracticalLifeScreenState();
}

class _PracticalLifeScreenState extends State<PracticalLifeScreen> {
  final _ext = ExtendedRepository(AppDatabase.instance);
  List<Map<String, Object?>> _docs = [];
  List<Map<String, Object?>> _practical = [];
  List<Map<String, Object?>> _appointments = [];
  List<Map<String, Object?>> _shopping = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final docs = await _ext.listDocuments();
    final practical = await _ext.listPractical();
    final appts = await _ext.listUpcomingAppointments(days: 30);
    final shop = await _ext.listShoppingLists();
    if (!mounted) return;
    setState(() {
      _docs = docs;
      _practical = practical;
      _appointments = appts;
      _shopping = shop;
      _loading = false;
    });
  }

  Future<void> _addDocument() async {
    final title = TextEditingController();
    DateTime? expires;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppTheme.metal,
          title: const Text('Document', style: TextStyle(color: AppTheme.silver)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                style: const TextStyle(color: AppTheme.silver),
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  expires == null
                      ? 'Expiry date (optional)'
                      : 'Expires ${expires!.year}-${expires!.month}-${expires!.day}',
                  style: const TextStyle(color: AppTheme.silver, fontSize: 14),
                ),
                trailing: const Icon(Icons.event, color: AppTheme.amber),
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setLocal(() => expires = d);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true || title.text.trim().isEmpty) return;
    await _ext.addDocument(title.text.trim(), expiresAt: expires);
    await _load();
  }

  Future<void> _addAppointment() async {
    final title = TextEditingController();
    var when = DateTime.now().add(const Duration(hours: 2));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppTheme.metal,
          title: const Text('Appointment', style: TextStyle(color: AppTheme.silver)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                style: const TextStyle(color: AppTheme.silver),
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${when.year}-${when.month}-${when.day} ${when.hour}:${when.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: AppTheme.silver),
                ),
                trailing: const Icon(Icons.edit_calendar, color: AppTheme.amber),
                onTap: () async {
                  final d = await showDatePicker(
                      context: ctx, initialDate: when, firstDate: DateTime(2020), lastDate: DateTime(2100));
                  if (d == null) return;
                  final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(when));
                  setLocal(() {
                    when = DateTime(d.year, d.month, d.day, t?.hour ?? when.hour, t?.minute ?? when.minute);
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true || title.text.trim().isEmpty) return;
    await _ext.addAppointment(title: title.text.trim(), start: when);
    await _load();
  }

  Future<void> _addVehicle() async {
    final title = TextEditingController();
    DateTime? due;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppTheme.metal,
          title: const Text('Vehicle / service', style: TextStyle(color: AppTheme.silver)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                style: const TextStyle(color: AppTheme.silver),
                decoration: const InputDecoration(labelText: 'e.g. Oil change'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(due == null ? 'Due date' : 'Due ${due!.month}/${due!.day}',
                    style: const TextStyle(color: AppTheme.silver)),
                trailing: const Icon(Icons.event, color: AppTheme.amber),
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setLocal(() => due = d);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true || title.text.trim().isEmpty) return;
    await _ext.addVehicleService(title: title.text.trim(), dueAt: due);
    await _load();
  }

  Future<void> _addShopping() async {
    final name = TextEditingController(text: 'Groceries');
    final item = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('Shopping list', style: TextStyle(color: AppTheme.silver)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              style: const TextStyle(color: AppTheme.silver),
              decoration: const InputDecoration(labelText: 'List name'),
            ),
            TextField(
              controller: item,
              style: const TextStyle(color: AppTheme.silver),
              decoration: const InputDecoration(labelText: 'First item (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    final id = await _ext.addShoppingList(name.text.trim());
    if (item.text.trim().isNotEmpty) await _ext.addShoppingItem(id, item.text.trim());
    await _load();
  }

  Future<void> _openShopping(String listId, String listName) async {
    final items = await _ext.listShoppingItems(listId);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.metal,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(listName, style: const TextStyle(color: AppTheme.silver, fontWeight: FontWeight.w700)),
                  ...items.map((it) => CheckboxListTile(
                        value: (it['purchased'] as int?) == 1,
                        title: Text('${it['name']}', style: const TextStyle(color: AppTheme.silver)),
                        activeColor: AppTheme.amber,
                        onChanged: (v) async {
                          await _ext.toggleShoppingItem(it['id'] as String, v == true);
                          final refreshed = await _ext.listShoppingItems(listId);
                          setLocal(() {
                            items
                              ..clear()
                              ..addAll(refreshed);
                          });
                        },
                      )),
                  TextButton(
                    onPressed: () async {
                      final c = TextEditingController();
                      final name = await showDialog<String>(
                        context: ctx,
                        builder: (dctx) => AlertDialog(
                          title: const Text('Item'),
                          content: TextField(controller: c, autofocus: true),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Cancel')),
                            FilledButton(
                              onPressed: () => Navigator.pop(dctx, c.text.trim()),
                              child: const Text('Add'),
                            ),
                          ],
                        ),
                      );
                      if (name != null && name.isNotEmpty) {
                        await _ext.addShoppingItem(listId, name);
                        final refreshed = await _ext.listShoppingItems(listId);
                        setLocal(() {
                          items
                            ..clear()
                            ..addAll(refreshed);
                        });
                      }
                    },
                    child: const Text('Add item'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      await _ext.completeShoppingList(listId);
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _load();
                    },
                    child: const Text('Complete list'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Practical life')),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.amber))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _header('Documents', _addDocument),
                  if (_docs.isEmpty)
                    _empty('ID, insurance, permits — track expiry.')
                  else
                    ..._docs.map((d) => ListTile(
                          title: Text('${d['title']}', style: const TextStyle(color: AppTheme.silver)),
                          subtitle: Text(
                            d['expires_at'] == null
                                ? '${d['document_type']}'
                                : 'Expires ${_fmt(d['expires_at'] as int)}',
                            style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11),
                          ),
                        )),
                  _header('Appointments', _addAppointment),
                  if (_appointments.isEmpty)
                    _empty('No upcoming appointments.')
                  else
                    ..._appointments.map((e) => ListTile(
                          title: Text('${e['title']}', style: const TextStyle(color: AppTheme.silver)),
                          subtitle: Text(_fmt(e['start_at'] as int),
                              style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11)),
                        )),
                  _header('Vehicle / service', _addVehicle),
                  if (_practical.where((p) => p['type'] == 'VEHICLE').isEmpty)
                    _empty('Service due dates stay in one place.')
                  else
                    ..._practical.where((p) => p['type'] == 'VEHICLE').map((p) => ListTile(
                          title: Text('${p['title']}', style: const TextStyle(color: AppTheme.silver)),
                          subtitle: Text(
                            p['due_at'] == null ? 'No due date' : 'Due ${_fmt(p['due_at'] as int)}',
                            style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.check, color: AppTheme.amber),
                            onPressed: () async {
                              await _ext.completePractical(p['id'] as String);
                              await _load();
                            },
                          ),
                        )),
                  _header('Shopping', _addShopping),
                  if (_shopping.isEmpty)
                    _empty('Lists for groceries and errands.')
                  else
                    ..._shopping.map((s) => ListTile(
                          title: Text('${s['name']}', style: const TextStyle(color: AppTheme.silver)),
                          trailing: const Icon(Icons.chevron_right, color: AppTheme.silverMuted),
                          onTap: () => _openShopping(s['id'] as String, '${s['name']}'),
                        )),
                ],
              ),
      ),
    );
  }

  Widget _header(String label, VoidCallback onAdd) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Row(
          children: [
            Text(label, style: const TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton(onPressed: onAdd, child: const Text('Add')),
          ],
        ),
      );

  Widget _empty(String m) =>
      Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(m, style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35))));

  String _fmt(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
