import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/link_repository.dart';
import '../../data/note_repository.dart';
import '../../data/project_repository.dart';
import '../../data/task_repository.dart';
import '../../domain/models.dart';
import '../theme.dart';
import '../widgets/glass.dart';

class NoteDetailScreen extends StatefulWidget {
  const NoteDetailScreen({super.key, required this.noteId});

  final String noteId;

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  Note? _note;
  List<Map<String, Object?>> _links = [];
  bool _loading = true;
  bool _editing = false;
  late TextEditingController _content;

  @override
  void initState() {
    super.initState();
    _content = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final n = await NoteRepository(AppDatabase.instance).getById(widget.noteId);
    final links = await LinkRepository(AppDatabase.instance).linksFor('NOTE', widget.noteId);
    setState(() {
      _note = n;
      _links = links;
      if (n != null) _content.text = n.content;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_content.text.trim().isEmpty) return;
    await NoteRepository(AppDatabase.instance).update(
      id: widget.noteId,
      content: _content.text.trim(),
    );
    setState(() => _editing = false);
    await _load();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('Delete note?', style: TextStyle(color: AppTheme.silver)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await NoteRepository(AppDatabase.instance).delete(widget.noteId);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _linkEntity() async {
    final tasks = await TaskRepository(AppDatabase.instance).listOpen();
    final projects = await ProjectRepository(AppDatabase.instance).listActive();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.metal,
      builder: (ctx) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Link note to…', style: TextStyle(color: AppTheme.silver, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            const Text('Tasks', style: TextStyle(color: AppTheme.woodLight, fontSize: 12)),
            ...tasks.map((t) => ListTile(
                  title: Text(t.title, style: const TextStyle(color: AppTheme.silver)),
                  onTap: () async {
                    await NoteRepository(AppDatabase.instance).linkTo(
                      noteId: widget.noteId,
                      targetType: 'TASK',
                      targetId: t.id,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _load();
                  },
                )),
            const Text('Projects', style: TextStyle(color: AppTheme.woodLight, fontSize: 12)),
            ...projects.map((p) => ListTile(
                  title: Text(p.title, style: const TextStyle(color: AppTheme.silver)),
                  onTap: () async {
                    await NoteRepository(AppDatabase.instance).linkTo(
                      noteId: widget.noteId,
                      targetType: 'PROJECT',
                      targetId: p.id,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _load();
                  },
                )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.amber)));
    }
    final n = _note;
    if (n == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Note not found')));
    }
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(n.title ?? 'Note'),
          actions: [
            if (_editing)
              IconButton(icon: const Icon(Icons.check), onPressed: _save)
            else
              IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => setState(() => _editing = true)),
            IconButton(icon: const Icon(Icons.link), onPressed: _linkEntity),
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_editing)
              TextField(
                controller: _content,
                maxLines: 12,
                style: const TextStyle(color: AppTheme.silver, height: 1.4),
                decoration: const InputDecoration(labelText: 'Content'),
              )
            else
              GlassCard(
                child: Text(n.content, style: const TextStyle(color: AppTheme.silver, height: 1.4)),
              ),
            const SizedBox(height: 16),
            const Text('Links', style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_links.isEmpty)
              Text(
                'Not linked yet — connect to a task or project for memory.',
                style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)),
              )
            else
              ..._links.map((l) {
                final isSource = l['source_id'] == widget.noteId;
                final type = isSource ? l['target_type'] : l['source_type'];
                final id = isSource ? l['target_id'] : l['source_id'];
                return ListTile(
                  dense: true,
                  title: Text('$type', style: const TextStyle(color: AppTheme.silver)),
                  subtitle: Text('$id', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11)),
                );
              }),
          ],
        ),
      ),
    );
  }
}
