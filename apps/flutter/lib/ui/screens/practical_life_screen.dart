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
    final practical = await _ext.listPracticalItems();
    final appointments = await _ext.listUpcomingEvents(days: 30);
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

  Future<void> _addDoc() async {
    final title = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('Document'),
        content: TextField(
          controller: title,
          style: const TextStyle(color: AppTheme.silver),
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, title.text.trim().isNotEmpty),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _ext.addDocument(title.text.trim());
    await _load();
  }

  Future<void> _addPractical() async {
    final title = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('Practical item'),
        content: TextField(
          controller: title,
          style: const TextStyle(color: AppTheme.silver),
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, title.text.trim().isNotEmpty),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _ext.addPracticalItem(title.text.trim());
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
          decoration: const InputDecoration(labelText: 'Name'),
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

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Practical life')),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.amber))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _section('Documents', _addDoc, _docs, (d) => '${d['title']}'),
                  _section('Items', _addPractical, _practical, (d) => '${d['title']}'),
                  _section('Shopping', _addShopping, _shopping, (d) => '${d['name']}'),
                  const Padding(
                    padding: EdgeInsets.only(top: 12, bottom: 8),
                    child: Text('Appointments / events',
                        style: TextStyle(
                            color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                  ),
                  if (_appointments.isEmpty)
                    Text('None upcoming',
                        style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4)))
                  else
                    ..._appointments.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GlassCard(
                            child: Text('${e['title']}',
                                style: const TextStyle(color: AppTheme.silver)),
                          ),
                        )),
                ],
              ),
      ),
    );
  }

  Widget _section(
    String title,
    VoidCallback onAdd,
    List<Map<String, Object?>> rows,
    String Function(Map<String, Object?>) label,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
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
        if (rows.isEmpty)
          Text('None',
              style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4)))
        else
          ...rows.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  child: Text(label(d), style: const TextStyle(color: AppTheme.silver)),
                ),
              )),
      ],
    );
  }
}
