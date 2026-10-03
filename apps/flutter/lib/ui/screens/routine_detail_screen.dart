import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/routine_repository.dart';
import '../../domain/models.dart';
import '../theme.dart';
import '../widgets/glass.dart';

class RoutineDetailScreen extends StatefulWidget {
  const RoutineDetailScreen({super.key, required this.routineId});

  final String routineId;

  @override
  State<RoutineDetailScreen> createState() => _RoutineDetailScreenState();
}

class _RoutineDetailScreenState extends State<RoutineDetailScreen> {
  final _repo = RoutineRepository(AppDatabase.instance);
  Routine? _routine;
  List<Map<String, Object?>> _steps = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await _repo.getById(widget.routineId);
    final steps = await _repo.listSteps(widget.routineId);
    if (!mounted) return;
    setState(() {
      _routine = r;
      _steps = steps;
      _loading = false;
    });
  }

  Future<void> _addStep() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('Add step'),
        content: TextField(
          controller: c,
          autofocus: true,
          style: const TextStyle(color: AppTheme.silver),
          decoration: const InputDecoration(labelText: 'Step title'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim().isNotEmpty),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.addStep(widget.routineId, c.text.trim());
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final r = _routine;
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(r?.name ?? 'Routine'),
          actions: [
            IconButton(
              tooltip: 'Complete today',
              onPressed: r == null
                  ? null
                  : () async {
                      await _repo.completeToday(r.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Completed ${r.name}')),
                        );
                      }
                    },
              icon: const Icon(Icons.done_all),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _addStep,
          child: const Icon(Icons.add),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.amber))
            : r == null
                ? const Center(child: Text('Not found', style: TextStyle(color: AppTheme.silver)))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    children: [
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.name,
                                style: const TextStyle(
                                    color: AppTheme.silver,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text('Status: ${r.status}',
                                style: TextStyle(
                                    color: AppTheme.silver.withValues(alpha: 0.5),
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Steps',
                          style: TextStyle(
                              color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      if (_steps.isEmpty)
                        Text('No steps yet — add the sequence for this routine.',
                            style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4)))
                      else
                        ..._steps.map((s) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: GlassCard(
                                child: ListTile(
                                  title: Text('${s['title']}',
                                      style: const TextStyle(color: AppTheme.silver)),
                                  subtitle: Text(
                                    s['estimated_minutes'] != null
                                        ? '${s['estimated_minutes']} min'
                                        : 'Step',
                                    style: TextStyle(
                                        color: AppTheme.silver.withValues(alpha: 0.4),
                                        fontSize: 11),
                                  ),
                                ),
                              ),
                            )),
                    ],
                  ),
      ),
    );
  }
}
