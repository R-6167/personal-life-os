import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/habit_repository.dart';
import '../../data/routine_repository.dart';
import '../../services/needs_attention.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import 'task_detail_screen.dart';
import 'project_detail_screen.dart';
import 'practical_life_screen.dart';

/// Defining feed: what needs attention across life — ranked by severity.
class NeedsAttentionScreen extends StatefulWidget {
  const NeedsAttentionScreen({super.key});

  @override
  State<NeedsAttentionScreen> createState() => _NeedsAttentionScreenState();
}

class _NeedsAttentionScreenState extends State<NeedsAttentionScreen> {
  final _svc = NeedsAttentionService();
  List<AttentionItem> _items = [];
  bool _loading = true;
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Block only the first load; later refreshes retain the visible feed.
    if (mounted && !_hasLoaded) setState(() => _loading = true);
    try {
      final items = await _svc.build();
      if (!mounted) return;
      setState(() {
        _items = items;
        _hasLoaded = true;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      final canKeepCurrentFeed = _hasLoaded;
      setState(() => _loading = false);
      if (canKeepCurrentFeed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not refresh attention items. Showing the last loaded version.')),
        );
      }
    }
  }

  Color _severityColor(AttentionSeverity s) {
    switch (s) {
      case AttentionSeverity.critical:
        return Colors.redAccent;
      case AttentionSeverity.high:
        return Colors.orangeAccent;
      case AttentionSeverity.medium:
        return AppTheme.amber;
    }
  }

  Future<void> _tap(AttentionItem a) async {
    switch (a.kind) {
      case AttentionKind.overdueTask:
      case AttentionKind.dueTask:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: a.id)),
        );
        break;
      case AttentionKind.projectNoNextAction:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: a.id)),
        );
        break;
      case AttentionKind.documentExpiring:
      case AttentionKind.documentExpired:
      case AttentionKind.practicalDue:
      case AttentionKind.vehicleService:
      case AttentionKind.warrantyExpiring:
      case AttentionKind.shoppingOpen:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PracticalLifeScreen()),
        );
        break;
      default:
        break;
    }
    await _load();
  }

  Future<void> _quickComplete(AttentionItem a) async {
    if (a.kind == AttentionKind.habitPending) {
      await HabitRepository(AppDatabase.instance).completeToday(a.id);
    } else if (a.kind == AttentionKind.routinePending) {
      await RoutineRepository(AppDatabase.instance).completeToday(a.id);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final critical = _items.where((i) => i.severity == AttentionSeverity.critical).length;
    final high = _items.where((i) => i.severity == AttentionSeverity.high).length;
    final medium = _items.where((i) => i.severity == AttentionSeverity.medium).length;

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Needs attention'),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: (_loading && !_hasLoaded)
            ? const Center(child: CircularProgressIndicator(color: AppTheme.amber))
            : _items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 48, color: AppTheme.silver.withValues(alpha: 0.35)),
                        const SizedBox(height: 12),
                        Text(
                          'Nothing urgent',
                          style: TextStyle(
                            color: AppTheme.silver.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Bills, docs, habits and projects look clear.',
                          style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4)),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: _items.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GlassCard(
                            child: Row(
                              children: [
                                _chip('🔴 $critical', Colors.redAccent),
                                const SizedBox(width: 8),
                                _chip('🟠 $high', Colors.orangeAccent),
                                const SizedBox(width: 8),
                                _chip('🟡 $medium', AppTheme.amber),
                              ],
                            ),
                          ),
                        );
                      }
                      final a = _items[i - 1];
                      final canQuick = a.kind == AttentionKind.habitPending ||
                          a.kind == AttentionKind.routinePending;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          onTap: () => _tap(a),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          child: ListTile(
                            leading: Text(a.badge, style: const TextStyle(fontSize: 18)),
                            title: Text(a.title,
                                style: TextStyle(
                                  color: AppTheme.silver,
                                  fontWeight: a.severity == AttentionSeverity.critical
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                )),
                            subtitle: Text(
                              a.subtitle,
                              style: TextStyle(
                                color: _severityColor(a.severity).withValues(alpha: 0.85),
                                fontSize: 12,
                              ),
                            ),
                            trailing: canQuick
                                ? IconButton(
                                    icon: const Icon(Icons.check_circle_outline,
                                        color: AppTheme.amber),
                                    onPressed: () => _quickComplete(a),
                                  )
                                : Icon(Icons.chevron_right,
                                    color: AppTheme.silver.withValues(alpha: 0.3)),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _chip(String label, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12)),
      );
}
