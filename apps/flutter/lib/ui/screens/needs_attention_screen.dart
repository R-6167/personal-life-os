import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/habit_repository.dart';
import '../../data/routine_repository.dart';
import '../../services/needs_attention.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import 'habit_detail_screen.dart';
import 'routine_detail_screen.dart';
import 'task_detail_screen.dart';

class NeedsAttentionScreen extends StatefulWidget {
  const NeedsAttentionScreen({super.key});

  @override
  State<NeedsAttentionScreen> createState() => _NeedsAttentionScreenState();
}

class _NeedsAttentionScreenState extends State<NeedsAttentionScreen> {
  List<AttentionItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await NeedsAttentionService().build();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _tap(AttentionItem a) async {
    switch (a.kind) {
      case AttentionKind.overdueTask:
      case AttentionKind.dueTask:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: a.id)),
        );
        break;
      case AttentionKind.habitPending:
      case AttentionKind.habitMissed:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => HabitDetailScreen(habitId: a.id)),
        );
        break;
      case AttentionKind.routinePending:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RoutineDetailScreen(routineId: a.id)),
        );
        break;
      case AttentionKind.routineMissed:
        await RoutineRepository(AppDatabase.instance).recoverMissed(a.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Routine occurrence recovered')),
          );
        }
        break;
      default:
        break;
    }
    await _load();
  }

  Future<void> _quickComplete(AttentionItem a) async {
    if (a.kind == AttentionKind.habitPending) {
      await HabitRepository(AppDatabase.instance).markDoneToday(a.id);
    } else if (a.kind == AttentionKind.routinePending) {
      await RoutineRepository(AppDatabase.instance).completeToday(a.id);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Needs attention'),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.amber))
            : _items.isEmpty
                ? Center(
                    child: Text(
                      'Nothing urgent — recurring life is clear.',
                      style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5)),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) {
                      final a = _items[i];
                      final canQuick = a.kind == AttentionKind.habitPending ||
                          a.kind == AttentionKind.routinePending;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          onTap: () => _tap(a),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          child: ListTile(
                            title: Text(a.title, style: const TextStyle(color: AppTheme.silver)),
                            subtitle: Text(a.subtitle,
                                style: TextStyle(
                                    color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12)),
                            trailing: canQuick
                                ? IconButton(
                                    icon: const Icon(Icons.check_circle_outline, color: AppTheme.amber),
                                    onPressed: () => _quickComplete(a),
                                  )
                                : Text('${a.urgency}',
                                    style: TextStyle(
                                        color: AppTheme.silver.withValues(alpha: 0.3), fontSize: 11)),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
