import 'package:flutter/material.dart';

import '../../services/activity_timeline.dart';
import '../theme.dart';
import '../widgets/glass.dart';

/// "Your Life Timeline" — personal history, not a database event log.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final _svc = ActivityTimelineService();
  List<TimelineDayGroup> _groups = [];
  bool _loading = true;
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted && !_hasLoaded) setState(() => _loading = true);
    final entries = await _svc.build(limit: 100);
    final groups = _svc.groupByDay(entries);
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _hasLoaded = true;
      _loading = false;
    });
  }

  Color _dotColor(String eventType) {
    if (eventType.contains('COMPLETED') ||
        eventType.contains('PAID') ||
        eventType.contains('REACHED')) {
      return const Color(0xFF6BCB77);
    }
    if (eventType.contains('MISSED') ||
        eventType.contains('DELETED') ||
        eventType.contains('SKIPPED')) {
      return Colors.orangeAccent;
    }
    if (eventType.contains('WORK_') || eventType.contains('SESSION')) {
      return AppTheme.amber;
    }
    if (eventType.contains('EXPENSE') ||
        eventType.contains('BILL') ||
        eventType.contains('DEBT')) {
      return AppTheme.woodLight;
    }
    return AppTheme.silver.withValues(alpha: 0.5);
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Your Life Timeline'),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: (_loading && !_hasLoaded)
            ? const Center(child: CircularProgressIndicator(color: AppTheme.amber))
            : _groups.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_stories_outlined,
                              size: 48, color: AppTheme.silver.withValues(alpha: 0.35)),
                          const SizedBox(height: 16),
                          Text(
                            'Your story starts here',
                            style: TextStyle(
                              color: AppTheme.silver.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Complete a task, pay a bill, or finish a routine —\nit will show up on this timeline.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.silver.withValues(alpha: 0.45),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    color: AppTheme.amber,
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                      itemCount: _groups.length,
                      itemBuilder: (ctx, gi) {
                        final g = _groups[gi];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(top: gi == 0 ? 4 : 20, bottom: 10),
                              child: Text(
                                g.label,
                                style: const TextStyle(
                                  color: AppTheme.woodLight,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            ...g.entries.map((e) {
                              final time = ActivityTimelineService.formatTime(e.occurredAt);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      SizedBox(
                                        width: 48,
                                        child: Column(
                                          children: [
                                            Text(
                                              time,
                                              style: TextStyle(
                                                color: AppTheme.silver.withValues(alpha: 0.55),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Expanded(
                                              child: Container(
                                                width: 2,
                                                color: AppTheme.silver.withValues(alpha: 0.12),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: GlassCard(
                                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                margin: const EdgeInsets.only(top: 4),
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: _dotColor(e.eventType),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      e.headline,
                                                      style: const TextStyle(
                                                        color: AppTheme.silver,
                                                        fontWeight: FontWeight.w600,
                                                        height: 1.35,
                                                      ),
                                                    ),
                                                    if (e.detail != null && e.detail!.isNotEmpty) ...[
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        e.detail!,
                                                        style: TextStyle(
                                                          color: AppTheme.silver.withValues(alpha: 0.45),
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
