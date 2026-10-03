import 'package:flutter/material.dart';

import '../../services/activity_timeline.dart';
import '../theme.dart';
import '../widgets/glass.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  List<TimelineEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await ActivityTimelineService().build();
    if (!mounted) return;
    setState(() {
      _entries = rows;
      _loading = false;
    });
  }

  String _fmt(int ms) {
    if (ms == 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Activity timeline'),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.amber))
            : _entries.isEmpty
                ? Center(
                    child: Text(
                      'No activity yet — actions across goals, tasks, habits, and finance are recorded here.',
                      style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4)),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: _entries.length,
                    itemBuilder: (ctx, i) {
                      final e = _entries[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 4,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppTheme.amber,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.headline,
                                      style: const TextStyle(
                                        color: AppTheme.silver,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      e.detail,
                                      style: TextStyle(
                                        color: AppTheme.silver.withValues(alpha: 0.55),
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _fmt(e.occurredAt),
                                      style: TextStyle(
                                        color: AppTheme.silver.withValues(alpha: 0.35),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
