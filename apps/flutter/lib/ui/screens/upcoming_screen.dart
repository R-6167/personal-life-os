import 'package:flutter/material.dart';

import '../../services/upcoming_service.dart';
import '../theme.dart';
import '../widgets/glass.dart';

class UpcomingScreen extends StatefulWidget {
  const UpcomingScreen({super.key});

  @override
  State<UpcomingScreen> createState() => _UpcomingScreenState();
}

class _UpcomingScreenState extends State<UpcomingScreen> {
  List<UpcomingItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await UpcomingService().build();
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  String _when(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = day.difference(today).inDays;
    final time =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (diff == 0) return 'Today · $time';
    if (diff == 1) return 'Tomorrow · $time';
    if (diff < 0) return 'Past due';
    return '${d.month}/${d.day} · $time';
  }

  IconData _icon(String kind) {
    switch (kind) {
      case 'bill':
        return Icons.receipt_long;
      case 'appointment':
        return Icons.event;
      case 'habit':
        return Icons.repeat;
      case 'routine':
        return Icons.playlist_play;
      default:
        return Icons.check_box_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Upcoming')),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.amber))
            : _items.isEmpty
                ? Center(
                    child: Text(
                      'Nothing upcoming in the next two weeks.',
                      style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4)),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) {
                      final it = _items[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(_icon(it.kind), color: AppTheme.amber),
                            title: Text(it.title, style: const TextStyle(color: AppTheme.silver)),
                            subtitle: Text(
                              '${it.subtitle} · ${_when(it.whenMs)}',
                              style: TextStyle(
                                color: AppTheme.silver.withValues(alpha: 0.45),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
