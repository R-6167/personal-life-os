import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/export_service.dart';
import '../theme.dart';
import '../widgets/glass.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  List<Map<String, Object?>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await ExportService(AppDatabase.instance).recentActivity();
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  String _fmt(int? ms) {
    if (ms == null) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Activity')),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.amber))
            : _rows.isEmpty
                ? Center(
                    child: Text(
                      'No activity yet — actions you take are recorded here.',
                      style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4)),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: _rows.length,
                    itemBuilder: (ctx, i) {
                      final r = _rows[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${r['event_type']}',
                                style: const TextStyle(color: AppTheme.amber, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${r['entity_type']} · ${_fmt(r['occurred_at'] as int?)}',
                                style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5), fontSize: 12),
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
