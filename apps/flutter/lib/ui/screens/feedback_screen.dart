import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/database.dart';
import '../../data/feedback_repository.dart';
import '../../services/local_analytics.dart';
import '../theme.dart';
import '../widgets/glass.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _repo = FeedbackRepository(AppDatabase.instance);
  List<Map<String, Object?>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    LocalAnalytics.instance.screenView('feedback');
    _load();
  }

  Future<void> _load() async {
    final items = await _repo.list();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final title = TextEditingController();
    final body = TextEditingController();
    var kind = 'FEEDBACK';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppTheme.metal,
          title: const Text('New note', style: TextStyle(color: AppTheme.silver)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: kind,
                dropdownColor: AppTheme.metal,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'FEEDBACK', child: Text('Feedback')),
                  DropdownMenuItem(value: 'BUG', child: Text('Bug')),
                  DropdownMenuItem(value: 'IDEA', child: Text('Idea')),
                ],
                onChanged: (v) => setLocal(() => kind = v ?? kind),
              ),
              TextField(
                controller: title,
                style: const TextStyle(color: AppTheme.silver),
                decoration: const InputDecoration(labelText: 'Title *'),
              ),
              TextField(
                controller: body,
                maxLines: 4,
                style: const TextStyle(color: AppTheme.silver),
                decoration: const InputDecoration(labelText: 'Details'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _repo.create(
      title: title.text.trim(),
      body: body.text.trim().isEmpty ? null : body.text.trim(),
      kind: kind,
    );
    await LocalAnalytics.instance.track('feedback_created', props: {'kind': kind});
    await _load();
  }

  Future<void> _shareAll() async {
    final text = await _repo.exportText();
    await Share.share(text, subject: 'PLOS feedback');
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Feedback & bugs'),
          actions: [
            IconButton(icon: const Icon(Icons.ios_share), onPressed: _shareAll),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: const Text('Add'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.amber))
            : _items.isEmpty
                ? Center(
                    child: Text(
                      'Log feedback or bugs offline.\nShare later when you choose.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4)),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) {
                      final r = _items[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${r['title']}',
                              style: const TextStyle(color: AppTheme.silver, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${r['kind']} · ${r['status']}'
                              '${r['body'] != null ? '\n${r['body']}' : ''}',
                              style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5), fontSize: 12),
                            ),
                            isThreeLine: r['body'] != null,
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'close') await _repo.close(r['id'] as String);
                                if (v == 'delete') await _repo.delete(r['id'] as String);
                                await _load();
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'close', child: Text('Mark closed')),
                                PopupMenuItem(value: 'delete', child: Text('Delete')),
                              ],
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
