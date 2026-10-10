import 'package:flutter/material.dart';

import '../../services/app_data_bus.dart';

import '../../data/bill_repository.dart';
import '../../data/database.dart';
import '../../data/extended_repository.dart';
import '../../data/goal_repository.dart';
import '../../data/link_repository.dart';
import '../../data/note_repository.dart';
import '../../data/project_repository.dart';
import '../../data/task_repository.dart';
import '../../domain/models.dart';
import '../../services/note_intelligence.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import 'project_detail_screen.dart';
import 'task_detail_screen.dart';

/// Memory layer: note body + links to life entities + extract tasks + AI mentions.
class NoteDetailScreen extends StatefulWidget {
  const NoteDetailScreen({super.key, required this.noteId});

  final String noteId;

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  Note? _note;
  final List<_ResolvedLink> _links = [];
  List<LinkSuggestion> _suggestions = [];
  final Set<String> _pickedSuggestions = {};
  bool _loading = true;
  bool _editing = true;
  bool _scanning = false;
  late TextEditingController _content;
  late TextEditingController _title;

  @override
  void initState() {
    super.initState();
    _content = TextEditingController();
    _title = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _content.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
    final n = await NoteRepository(AppDatabase.instance).getById(widget.noteId);
    final raw = await LinkRepository(AppDatabase.instance).linksFor('NOTE', widget.noteId);
    final resolved = <_ResolvedLink>[];
    final links = LinkRepository(AppDatabase.instance);
    for (final row in raw) {
      final peer = LinkRepository.peerOf(row, 'NOTE', widget.noteId);
      final type = peer['type'] ?? '';
      final id = peer['id'] ?? '';
      if (type.isEmpty || id.isEmpty) continue;
      final label = await links.resolveTitle(type, id) ?? type;
      resolved.add(_ResolvedLink(
        linkId: '${row['id']}',
        type: type,
        id: id,
        label: label,
        relation: '${row['relation'] ?? row['relationship_type'] ?? 'RELATED'}',
      ));
    }
    if (!mounted) return;
    setState(() {
      _note = n;
      _links
        ..clear()
        ..addAll(resolved);
      if (n != null) {
        _content.text = n.content;
        _title.text = n.title ?? '';
      }
      _loading = false;
    });
    if (n != null) {
      await _scanMentions(content: n.content, title: n.title);
    }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Note data unavailable: $e')),
      );
    }
  }

  Future<void> _scanMentions({required String content, String? title}) async {
    setState(() => _scanning = true);
    final suggestions = await NoteIntelligence().suggestLinks(
      noteId: widget.noteId,
      content: content,
      title: title,
    );
    if (!mounted) return;
    setState(() {
      _suggestions = suggestions;
      _pickedSuggestions
        ..clear()
        ..addAll(suggestions.where((s) => s.score >= 0.85).map((s) => '${s.entityType}:${s.entityId}'));
      _scanning = false;
    });
  }

  Future<void> _applyPickedSuggestions() async {
    final chosen = _suggestions
        .where((s) => _pickedSuggestions.contains('${s.entityType}:${s.entityId}'))
        .toList();
    if (chosen.isEmpty) return;
    final n = await NoteIntelligence().applyLinkSuggestions(
      noteId: widget.noteId,
      suggestions: chosen,
    );
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Linked $n mention${n == 1 ? '' : 's'}')),
      );
    }
  }

  Future<void> _save() async {
    if (_content.text.trim().isEmpty) return;
    await NoteRepository(AppDatabase.instance).update(
      id: widget.noteId,
      title: _title.text.trim().isEmpty ? null : _title.text.trim(),
      content: _content.text.trim(),
    );
    AppDataBus.instance.lifeChanged();
      setState(() => _editing = false);
    try {
      await NoteIntelligence().autoLinkStrongMentions(
        noteId: widget.noteId,
        content: _content.text.trim(),
        title: _title.text.trim().isEmpty ? null : _title.text.trim(),
      );
    } catch (_) {}
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
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.metal,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('Link this note to…',
                  style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
            ),
            _typeTile(ctx, 'PROJECT', 'Project', Icons.folder_outlined),
            _typeTile(ctx, 'GOAL', 'Goal', Icons.flag_outlined),
            _typeTile(ctx, 'TASK', 'Task', Icons.check_box_outlined),
            _typeTile(ctx, 'PERSON', 'Person', Icons.person_outline),
            _typeTile(ctx, 'EVENT', 'Event', Icons.event),
            _typeTile(ctx, 'BILL', 'Bill', Icons.receipt_long),
            _typeTile(ctx, 'PRACTICAL', 'Practical item', Icons.handyman_outlined),
            _typeTile(ctx, 'HABIT', 'Habit', Icons.repeat),
          ],
        ),
      ),
    );
    if (choice == null) return;
    await _pickTarget(choice);
  }

  Widget _typeTile(BuildContext ctx, String type, String label, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.amber),
      title: Text(label, style: const TextStyle(color: AppTheme.silver)),
      onTap: () => Navigator.pop(ctx, type),
    );
  }

  Future<void> _pickTarget(String type) async {
    final options = await _loadOptions(type);
    if (!mounted) return;
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No ${type.toLowerCase()}s to link yet')),
      );
      return;
    }
    final picked = await showModalBottomSheet<Map<String, String>>(
      context: context,
      backgroundColor: AppTheme.metal,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text('Choose $type',
                  style: const TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
            ),
            ...options.map(
              (o) => ListTile(
                title: Text(o['label']!, style: const TextStyle(color: AppTheme.silver)),
                onTap: () => Navigator.pop(ctx, o),
              ),
            ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await NoteRepository(AppDatabase.instance).linkTo(
      noteId: widget.noteId,
      targetType: type,
      targetId: picked['id']!,
    );
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Linked to ${picked['label']}')),
      );
    }
  }

  Future<List<Map<String, String>>> _loadOptions(String type) async {
    final db = AppDatabase.instance;
    switch (type) {
      case 'TASK':
        return [for (final t in await TaskRepository(db).listOpen()) {'id': t.id, 'label': t.title}];
      case 'PROJECT':
        return [for (final p in await ProjectRepository(db).listActive()) {'id': p.id, 'label': p.title}];
      case 'GOAL':
        return [for (final g in await GoalRepository(db).listActive()) {'id': g.id, 'label': g.title}];
      case 'PERSON':
        return [
          for (final p in await ExtendedRepository(db).listPeople())
            {'id': '${p['id']}', 'label': '${p['name']}'}
        ];
      case 'EVENT':
        return [
          for (final e in await ExtendedRepository(db).listUpcomingAppointments(days: 60))
            {'id': '${e['id']}', 'label': '${e['title']}'}
        ];
      case 'BILL':
        return [for (final b in await BillRepository(db).listActive()) {'id': b.id, 'label': b.name}];
      case 'PRACTICAL':
        return [
          for (final p in await ExtendedRepository(db).listPractical())
            {'id': '${p['id']}', 'label': '${p['title']}'}
        ];
      case 'HABIT':
        final rows = await (await db.database).query(
          'habits',
          where: "status = 'ACTIVE'",
          orderBy: 'title ASC',
        );
        return [for (final h in rows) {'id': '${h['id']}', 'label': '${h['title']}'}];
      default:
        return [];
    }
  }

  Future<void> _extractTasks() async {
    final content = _note?.content ?? _content.text;
    final candidates = NoteIntelligence.extractTaskCandidates(content);
    if (candidates.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No action lines found. Use bullets, TODO:, or [ ] lines.'),
          ),
        );
      }
      return;
    }

    final selected = Set<String>.from(candidates);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppTheme.metal,
          title: const Text('Turn into tasks',
              style: TextStyle(color: AppTheme.silver, fontSize: 16)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(
                  'Select lines to create as tasks (linked back to this note).',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5), fontSize: 12),
                ),
                const SizedBox(height: 8),
                ...candidates.map(
                  (c) => CheckboxListTile(
                    value: selected.contains(c),
                    activeColor: AppTheme.amber,
                    title: Text(c, style: const TextStyle(color: AppTheme.silver, fontSize: 13)),
                    onChanged: (v) {
                      setLocal(() {
                        if (v == true) {
                          selected.add(c);
                        } else {
                          selected.remove(c);
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: selected.isEmpty ? null : () => Navigator.pop(ctx, true),
              child: Text('Create ${selected.length}'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || selected.isEmpty) return;

    String? projectId;
    String? goalId;
    for (final l in _links) {
      if (l.type == 'PROJECT') projectId ??= l.id;
      if (l.type == 'GOAL') goalId ??= l.id;
    }

    final n = await NoteIntelligence().createTasksFromNote(
      noteId: widget.noteId,
      titles: selected.toList(),
      projectId: projectId,
      goalId: goalId,
    );
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created $n task${n == 1 ? '' : 's'} from this note')),
      );
    }
  }

  Future<void> _openLink(_ResolvedLink l) async {
    if (l.type == 'TASK') {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: l.id)),
      );
    } else if (l.type == 'PROJECT') {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: l.id)),
      );
    }
    await _load();
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'PROJECT':
        return Icons.folder_outlined;
      case 'GOAL':
        return Icons.flag_outlined;
      case 'TASK':
        return Icons.check_box_outlined;
      case 'PERSON':
        return Icons.person_outline;
      case 'EVENT':
      case 'CALENDAR_EVENT':
        return Icons.event;
      case 'BILL':
        return Icons.receipt_long;
      case 'PRACTICAL':
        return Icons.handyman_outlined;
      case 'HABIT':
        return Icons.repeat;
      default:
        return Icons.link;
    }
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
          title: Text(_editing ? 'Edit note' : (n.title?.isNotEmpty == true ? n.title! : 'Note')),
          actions: [
            if (_editing)
              IconButton(icon: const Icon(Icons.check), onPressed: _save)
            else ...[
              IconButton(
                tooltip: 'Suggest links from text',
                icon: const Icon(Icons.auto_awesome),
                onPressed: () async {
                  final note = _note;
                  if (note == null) return;
                  await _scanMentions(content: note.content, title: note.title);
                },
              ),
              IconButton(
                tooltip: 'Turn into tasks',
                icon: const Icon(Icons.playlist_add_check),
                onPressed: _extractTasks,
              ),
              IconButton(icon: const Icon(Icons.link), onPressed: _linkEntity),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => setState(() => _editing = true),
              ),
              IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
            ],
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (_editing) ...[
              TextField(
                controller: _title,
                style: const TextStyle(color: AppTheme.silver, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(labelText: 'Title (optional)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _content,
                maxLines: 14,
                style: const TextStyle(color: AppTheme.silver, height: 1.45),
                decoration: const InputDecoration(
                  labelText: 'Note',
                  alignLabelWithHint: true,
                  hintText: 'Mention Project Alpha, @Amina, electricity bill…',
                ),
              ),
            ] else ...[
              GlassCard(
                child: Text(
                  n.content,
                  style: const TextStyle(color: AppTheme.silver, height: 1.45),
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (_scanning)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(color: AppTheme.amber, minHeight: 2),
              ),
            if (_suggestions.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppTheme.amber, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Suggested links',
                      style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: _applyPickedSuggestions,
                    child: const Text('Link selected'),
                  ),
                ],
              ),
              Text(
                'Ordin found names in this note that match your life data.',
                style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _suggestions.map((s) {
                  final key = '${s.entityType}:${s.entityId}';
                  final selected = _pickedSuggestions.contains(key);
                  return FilterChip(
                    selected: selected,
                    label: Text('${s.entityType}: ${s.label}'),
                    selectedColor: AppTheme.amber.withValues(alpha: 0.25),
                    checkmarkColor: AppTheme.amber,
                    labelStyle: TextStyle(
                      color: selected ? AppTheme.silver : AppTheme.silver.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _pickedSuggestions.add(key);
                        } else {
                          _pickedSuggestions.remove(key);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Memory links',
                    style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton.icon(
                  onPressed: _linkEntity,
                  icon: const Icon(Icons.add_link, size: 18),
                  label: const Text('Link'),
                ),
              ],
            ),
            Text(
              'Project · Goal · Task · Person · Event · Bill · Practical',
              style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11),
            ),
            const SizedBox(height: 8),
            if (_links.isEmpty)
              Text(
                'Not linked yet — write entity names in the note, or link manually.',
                style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)),
              )
            else
              ..._links.map(
                (l) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    onTap: () => _openLink(l),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(_iconFor(l.type), color: AppTheme.amber, size: 22),
                      title: Text(l.label, style: const TextStyle(color: AppTheme.silver)),
                      subtitle: Text(
                        '${l.type}${l.relation != 'RELATED' ? ' · ${l.relation}' : ''}',
                        style: TextStyle(
                            color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.close,
                            size: 18, color: AppTheme.silver.withValues(alpha: 0.35)),
                        onPressed: () async {
                          await LinkRepository(AppDatabase.instance).unlink(l.linkId);
                          await _load();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _extractTasks,
              icon: const Icon(Icons.playlist_add_check),
              label: const Text('Turn lines into tasks'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResolvedLink {
  _ResolvedLink({
    required this.linkId,
    required this.type,
    required this.id,
    required this.label,
    required this.relation,
  });

  final String linkId;
  final String type;
  final String id;
  final String label;
  final String relation;
}
