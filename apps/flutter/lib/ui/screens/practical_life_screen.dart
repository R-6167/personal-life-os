import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/extended_repository.dart';
import '../theme.dart';
import '../widgets/glass.dart';

/// Documents, vehicle service, maintenance, warranties, shopping, appointments.
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
    final appointments = await _ext.listUpcomingAppointments(days: 30);
    final shopping = await _ext.listShoppingLists();
    if (!mounted) return;
    setState(() {
      _docs = docs;
      _practical = practical;
      _appointments = appointments;
      _shopping = shopping;
      _loading = false;
    });
  }

  String _fmtDue(Object? ms) {
    if (ms is! int) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _addDoc() async {
    final title = TextEditingController();
    DateTime? expires;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppTheme.metal,
          title: const Text('Document'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                style: const TextStyle(color: AppTheme.silver),
                decoration:
                    const InputDecoration(labelText: 'Title (e.g. Driving licence)'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  expires == null
                      ? 'Expiry date (optional)'
                      : 'Expires ${_fmtDue(expires!.millisecondsSinceEpoch)}',
                  style: const TextStyle(color: AppTheme.silver, fontSize: 14),
                ),
                trailing: const Icon(Icons.event, color: AppTheme.amber),
                onTap: () async {
                  final p = await showDatePicker(
                    context: ctx,
                    initialDate: expires ?? DateTime.now().add(const Duration(days: 365)),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (p != null) setLocal(() => expires = p);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, title.text.trim().isNotEmpty),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _ext.addDocument(title.text.trim(), expiresAt: expires);
    await _load();
  }

  Future<void> _addPractical() async {
    final title = TextEditingController();
    var kind = 'HOUSEHOLD';
    DateTime? due;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppTheme.metal,
          title: const Text('Practical item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                style: const TextStyle(color: AppTheme.silver),
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              DropdownButtonFormField<String>(
                value: kind,
                dropdownColor: AppTheme.metal,
                decoration: const InputDecoration(labelText: 'Kind'),
                items: const [
                  DropdownMenuItem(value: 'HOUSEHOLD', child: Text('Household')),
                  DropdownMenuItem(value: 'VEHICLE', child: Text('Vehicle / service')),
                  DropdownMenuItem(value: 'MAINTENANCE', child: Text('Maintenance')),
                  DropdownMenuItem(value: 'WARRANTY', child: Text('Warranty')),
                  DropdownMenuItem(value: 'RENEWAL', child: Text('Renewal')),
                  DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                ],
                onChanged: (v) => setLocal(() => kind = v ?? kind),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  due == null
                      ? 'Due date (optional)'
                      : 'Due ${_fmtDue(due!.millisecondsSinceEpoch)}',
                  style: const TextStyle(color: AppTheme.silver, fontSize: 14),
                ),
                trailing: const Icon(Icons.event, color: AppTheme.amber),
                onTap: () async {
                  final p = await showDatePicker(
                    context: ctx,
                    initialDate: due ?? DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (p != null) setLocal(() => due = p);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, title.text.trim().isNotEmpty),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _ext.addPractical(title.text.trim(), type: kind, dueAt: due);
    await _load();
  }

  Future<void> _addShopping() async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('Shopping list'),
        content: TextField(
          controller: name,
          style: const TextStyle(color: AppTheme.silver),
          decoration: const InputDecoration(labelText: 'List name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, name.text.trim().isNotEmpty),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _ext.addShoppingList(name.text.trim());
    await _load();
  }

  Widget _section(String title, VoidCallback onAdd, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
              ),
              TextButton(onPressed: onAdd, child: const Text('Add')),
            ],
          ),
        ),
        if (children.isEmpty)
          Text('None yet',
              style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
        else
          ...children,
      ],
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
                  Text(
                    'Documents, vehicle, maintenance, warranties, shopping — all feed Needs Attention when due.',
                    style: TextStyle(
                        color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12),
                  ),
                  _section(
                    'Documents',
                    _addDoc,
                    _docs
                        .map((d) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: GlassCard(
                                child: ListTile(
                                  title: Text('${d['title']}',
                                      style: const TextStyle(color: AppTheme.silver)),
                                  subtitle: d['expires_at'] != null
                                      ? Text('Expires ${_fmtDue(d['expires_at'])}',
                                          style: TextStyle(
                                              color: AppTheme.silver.withValues(alpha: 0.45),
                                              fontSize: 12))
                                      : null,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  _section(
                    'Practical / vehicle / warranty',
                    _addPractical,
                    _practical
                        .map((p) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: GlassCard(
                                child: ListTile(
                                  title: Text('${p['title']}',
                                      style: const TextStyle(color: AppTheme.silver)),
                                  subtitle: Text(
                                    [
                                      if (p['kind'] != null) '${p['kind']}',
                                      if (p['due_at'] != null) 'due ${_fmtDue(p['due_at'])}',
                                    ].join(' · '),
                                    style: TextStyle(
                                        color: AppTheme.silver.withValues(alpha: 0.45),
                                        fontSize: 12),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.check, color: AppTheme.amber),
                                    onPressed: () async {
                                      await _ext.completePractical(p['id'] as String);
                                      await _load();
                                    },
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  _section(
                    'Appointments (next 30 days)',
                    () {},
                    _appointments
                        .map((a) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: GlassCard(
                                child: ListTile(
                                  title: Text('${a['title']}',
                                      style: const TextStyle(color: AppTheme.silver)),
                                  subtitle: a['start_at'] != null
                                      ? Text(_fmtDue(a['start_at']),
                                          style: TextStyle(
                                              color: AppTheme.silver.withValues(alpha: 0.45),
                                              fontSize: 12))
                                      : null,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  _section(
                    'Shopping lists',
                    _addShopping,
                    _shopping
                        .map((s) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: GlassCard(
                                child: ListTile(
                                  title: Text('${s['name']}',
                                      style: const TextStyle(color: AppTheme.silver)),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
      ),
    );
  }
}
