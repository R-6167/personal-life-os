import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/life_area_repository.dart';
import '../../domain/life_area.dart';
import '../../services/app_data_bus.dart';
import '../theme.dart';
import '../widgets/glass.dart';

/// Manage configurable life areas (work, health, finance, …).
class LifeAreasScreen extends StatefulWidget {
  const LifeAreasScreen({super.key});

  @override
  State<LifeAreasScreen> createState() => _LifeAreasScreenState();
}

class _LifeAreasScreenState extends State<LifeAreasScreen> {
  final _repo = LifeAreaRepository(AppDatabase.instance);
  List<LifeArea> _areas = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _repo.seedDefaultsIfEmpty();
    final list = await _repo.listActive();
    if (!mounted) return;
    setState(() {
      _areas = list;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final c = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metalDeep,
        title: const Text('New life area', style: TextStyle(color: AppTheme.silver)),
        content: TextField(
          controller: c,
          autofocus: true,
          style: const TextStyle(color: AppTheme.silver),
          decoration: const InputDecoration(
            hintText: 'e.g. Side projects',
            hintStyle: TextStyle(color: AppTheme.silverMuted),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (title == null || title.isEmpty) return;
    try {
      await _repo.create(title: title);
      AppDataBus.instance.lifeChanged();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add life area: $e')),
      );
    }
  }

  Future<void> _archive(LifeArea area) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metalDeep,
        title: const Text('Archive life area?', style: TextStyle(color: AppTheme.silver)),
        content: Text(
          '"${area.title}" will be hidden. Linked goals and projects keep their data.',
          style: const TextStyle(color: AppTheme.silverMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Archive')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.archive(area.id);
      AppDataBus.instance.lifeChanged();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not archive: $e')),
      );
    }
  }

  Future<void> _move(int index, int delta) async {
    final next = index + delta;
    if (next < 0 || next >= _areas.length) return;
    final ids = _areas.map((a) => a.id).toList();
    final tmp = ids[index];
    ids[index] = ids[next];
    ids[next] = tmp;
    try {
      await _repo.reorder(ids);
      AppDataBus.instance.lifeChanged();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not reorder: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDeep,
        title: const Text('Life areas', style: TextStyle(color: AppTheme.silver)),
        actions: [
          IconButton(
            tooltip: 'Add life area',
            icon: const Icon(Icons.add, color: AppTheme.amber),
            onPressed: _add,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.amber))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Organize goals and projects by domain of life. '
                  'Areas are configurable — not a fixed list.',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.55), height: 1.4),
                ),
                const SizedBox(height: 16),
                if (_areas.isEmpty)
                  Text(
                    'No life areas yet. Tap + to add one.',
                    style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4)),
                  )
                else
                  ..._areas.asMap().entries.map((entry) {
                    final i = entry.key;
                    final a = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassCard(
                        child: ListTile(
                          title: Text(a.title, style: const TextStyle(color: AppTheme.silver)),
                          subtitle: a.description == null || a.description!.isEmpty
                              ? null
                              : Text(
                                  a.description!,
                                  style: TextStyle(
                                    color: AppTheme.silver.withValues(alpha: 0.45),
                                    fontSize: 12,
                                  ),
                                ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Move up',
                                icon: const Icon(Icons.arrow_upward, size: 18, color: AppTheme.silver),
                                onPressed: i == 0 ? null : () => _move(i, -1),
                              ),
                              IconButton(
                                tooltip: 'Move down',
                                icon: const Icon(Icons.arrow_downward, size: 18, color: AppTheme.silver),
                                onPressed: i == _areas.length - 1 ? null : () => _move(i, 1),
                              ),
                              IconButton(
                                tooltip: 'Archive',
                                icon: const Icon(Icons.archive_outlined, size: 18, color: AppTheme.silverMuted),
                                onPressed: () => _archive(a),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
