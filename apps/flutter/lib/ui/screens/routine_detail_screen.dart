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
  String? _todayStatus;
  List<Map<String, Object?>> _missed = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await _repo.getById(widget.routineId);
    if (r != null) await _repo.ensureTodayOccurrence(r.id);
    final steps = await _repo.listSteps(widget.routineId);
    final st = await _repo.todayStatus(widget.routineId);
    final missed = await _repo.listMissed(limit: 5);
    if (!mounted) return;
    setState(() {
      _routine = r;
      _steps = steps;
      _todayStatus = st;
      _missed = missed.where((m) => m['routine_id'] == widget.routineId).toList();
      _loading = false;
    });
  }

  Future<void> _addStep() async {
    final c = TextEditingController();
    var optional = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppTheme.metal,
          title: const Text('Add step', style: TextStyle(color: AppTheme.silver)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: c,
                autofocus: true,
                style: const TextStyle(color: AppTheme.silver),
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              SwitchListTile(
                title: const Text('Optional', style: TextStyle(color: AppTheme.silver, fontSize: 14)),
                value: optional,
                activeColor: AppTheme.amber,
                onChanged: (v) => setLocal(() => optional = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (ok != true || c.text.trim().isEmpty) return;
    await _repo.addStep(widget.routineId, c.text.trim(), optional: optional);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.amber)));
    }
    final r = _routine;
    if (r == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Routine not found')));
    }
    final done = _todayStatus == 'COMPLETED';

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Routine')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.name,
                      style: const TextStyle(
                          color: AppTheme.silver, fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('Today: ${_todayStatus ?? 'EXPECTED'}',
                      style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: done
                        ? null
                        : () async {
                            await _repo.startToday(r.id);
                            await _load();
                          },
                    child: const Text('Start'),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: FilledButton(
                    onPressed: done
                        ? null
                        : () async {
                            await _repo.completeToday(r.id);
                            await _load();
                          },
                    child: Text(done ? 'Done' : 'Complete'),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    onPressed: done
                        ? null
                        : () async {
                            await _repo.skipToday(r.id);
                            await _load();
                          },
                    child: const Text('Skip'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Steps', style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(onPressed: _addStep, child: const Text('Add step')),
              ],
            ),
            if (_steps.isEmpty)
              Text('No steps — add flexible steps (optional allowed).',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4)))
            else
              ..._steps.map((s) => GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: ListTile(
                      title: Text('${s['title']}', style: const TextStyle(color: AppTheme.silver)),
                      subtitle: Text(
                        (s['optional'] as int?) == 1 ? 'Optional' : 'Required',
                        style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppTheme.silverMuted),
                        onPressed: () async {
                          await _repo.removeStep(s['id'] as String);
                          await _load();
                        },
                      ),
                    ),
                  )),
            if (_missed.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Missed — recover',
                  style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
              ..._missed.map((m) => ListTile(
                    title: Text('Missed occurrence', style: const TextStyle(color: AppTheme.silver)),
                    trailing: TextButton(
                      onPressed: () async {
                        await _repo.recoverMissed(m['id'] as String);
                        await _load();
                      },
                      child: const Text('Recover'),
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}
