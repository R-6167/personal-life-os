import '../data/database.dart';
import '../data/habit_repository.dart';
import '../data/note_repository.dart';
import '../data/task_repository.dart';
import '../domain/enums.dart';
import '../domain/models.dart';
import 'personal_context_engine.dart';

/// What the user is asking Ordin to *do* (not just answer).
enum OrdinIntentKind {
  none,
  completeTask,
  createTask,
  rescheduleTaskToday,
  rescheduleTaskTomorrow,
  addNote,
  createReminder,
  completeHabit,
  focusNext,
}

/// Structured, reversible proposal shown before any write.
class OrdinActionProposal {
  OrdinActionProposal({
    required this.id,
    required this.kind,
    required this.title,
    required this.rationale,
    required this.preview,
    this.entityType,
    this.entityId,
    this.payload = const {},
  });

  final String id;
  final OrdinIntentKind kind;
  final String title;
  final String rationale;
  final String preview;
  final String? entityType;
  final String? entityId;
  final Map<String, Object?> payload;

  bool get isActionable => kind != OrdinIntentKind.none;
}

class OrdinActionResult {
  OrdinActionResult({
    required this.ok,
    required this.message,
    this.entityType,
    this.entityId,
  });
  final bool ok;
  final String message;
  final String? entityType;
  final String? entityId;
}

/// Intent → context → reason → propose → (approve) → act → history.
class OrdinOperator {
  OrdinOperator({AppDatabase? db}) : _db = db ?? AppDatabase.instance;
  final AppDatabase _db;

  Future<List<OrdinActionProposal>> propose(String userMessage) async {
    final raw = userMessage.trim();
    if (raw.isEmpty) return const [];
    final q = raw.toLowerCase();
    final kind = _detectIntent(q, raw);
    if (kind == OrdinIntentKind.none) return const [];

    final situation = await PersonalContextEngine(db: _db).build();
    final tasks = TaskRepository(_db);

    switch (kind) {
      case OrdinIntentKind.completeTask:
        final match = await _matchTask(tasks, raw, q);
        if (match == null) {
          return [
            OrdinActionProposal(
              id: AppDatabase.newId(),
              kind: OrdinIntentKind.none,
              title: 'Could not find that task',
              rationale: 'No open task matched what you said.',
              preview: 'Try: complete “task title”',
            ),
          ];
        }
        return [
          OrdinActionProposal(
            id: AppDatabase.newId(),
            kind: OrdinIntentKind.completeTask,
            title: 'Complete task',
            rationale:
                'You asked to mark work done. “${match.title}” is open${match.isOverdue ? " and overdue" : ""}.',
            preview: 'Mark “${match.title}” completed',
            entityType: 'TASK',
            entityId: match.id,
          ),
        ];

      case OrdinIntentKind.createTask:
        final title = _extractQuoted(raw) ??
            _stripCommand(raw, const [
              'add task',
              'create task',
              'new task',
              'todo',
              'add',
            ]);
        if (title.length < 2) return const [];
        final pressure = situation.overdueCount > 0
            ? 'You already have ${situation.overdueCount} overdue — still adding this as planned work.'
            : 'Capacity today: ${situation.capacityLabel}.';
        return [
          OrdinActionProposal(
            id: AppDatabase.newId(),
            kind: OrdinIntentKind.createTask,
            title: 'Create task',
            rationale: pressure,
            preview: 'Create task “$title”',
            payload: {'title': title},
          ),
        ];

      case OrdinIntentKind.rescheduleTaskToday:
      case OrdinIntentKind.rescheduleTaskTomorrow:
        final match = await _matchTask(tasks, raw, q);
        final day = kind == OrdinIntentKind.rescheduleTaskToday
            ? DateTime.now()
            : DateTime.now().add(const Duration(days: 1));
        final label =
            kind == OrdinIntentKind.rescheduleTaskToday ? 'today' : 'tomorrow';
        if (match == null) {
          final open = await tasks.listOpen();
          final overdue = await tasks.listOverdue();
          final t = overdue.isNotEmpty
              ? overdue.first
              : (open.isNotEmpty ? open.first : null);
          if (t == null) return const [];
          return [
            OrdinActionProposal(
              id: AppDatabase.newId(),
              kind: kind,
              title: 'Reschedule to $label',
              rationale:
                  'No explicit title matched; proposing the top pressure item “${t.title}”.',
              preview: 'Move “${t.title}” due date to $label',
              entityType: 'TASK',
              entityId: t.id,
              payload: {
                'dayMs':
                    DateTime(day.year, day.month, day.day).millisecondsSinceEpoch
              },
            ),
          ];
        }
        return [
          OrdinActionProposal(
            id: AppDatabase.newId(),
            kind: kind,
            title: 'Reschedule to $label',
            rationale: 'You asked to move this work to $label.',
            preview: 'Move “${match.title}” due date to $label',
            entityType: 'TASK',
            entityId: match.id,
            payload: {
              'dayMs':
                  DateTime(day.year, day.month, day.day).millisecondsSinceEpoch
            },
          ),
        ];

      case OrdinIntentKind.addNote:
        final body = _extractQuoted(raw) ??
            _stripCommand(raw, const ['note', 'add note', 'write', 'journal']);
        if (body.length < 2) return const [];
        return [
          OrdinActionProposal(
            id: AppDatabase.newId(),
            kind: OrdinIntentKind.addNote,
            title: 'Add note',
            rationale: 'Capture this thought in your offline notes.',
            preview: body.length > 80 ? '${body.substring(0, 80)}…' : body,
            payload: {'content': body},
          ),
        ];

      case OrdinIntentKind.createReminder:
        final title = _extractQuoted(raw) ??
            _stripCommand(raw, const [
              'remind me',
              'reminder',
              'set reminder',
              'remind',
            ]);
        if (title.length < 2) return const [];
        final trigger =
            DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch;
        return [
          OrdinActionProposal(
            id: AppDatabase.newId(),
            kind: OrdinIntentKind.createReminder,
            title: 'Create reminder',
            rationale: 'Local reminder in ~1 hour (you can reschedule later).',
            preview: 'Remind: “$title”',
            payload: {'title': title, 'triggerAt': trigger},
          ),
        ];

      case OrdinIntentKind.completeHabit:
        final habits = await HabitRepository(_db).listActive();
        final match = _matchByTitle(
          habits.map((h) => (h.id, h.title)).toList(),
          raw,
          q,
        );
        if (match == null) return const [];
        return [
          OrdinActionProposal(
            id: AppDatabase.newId(),
            kind: OrdinIntentKind.completeHabit,
            title: 'Complete habit',
            rationale: 'Log today’s occurrence for this habit.',
            preview: 'Mark habit “${match.$2}” done for today',
            entityType: 'HABIT',
            entityId: match.$1,
          ),
        ];

      case OrdinIntentKind.focusNext:
        final op = situation.opportunities.isNotEmpty
            ? situation.opportunities.first
            : null;
        if (op == null || op.entityId == null) {
          return [
            OrdinActionProposal(
              id: AppDatabase.newId(),
              kind: OrdinIntentKind.none,
              title: 'No clear next action',
              rationale: situation.capacityLabel,
              preview: 'Try “situation” or open Planning → Build My Day',
            ),
          ];
        }
        return [
          OrdinActionProposal(
            id: AppDatabase.newId(),
            kind: OrdinIntentKind.completeTask,
            title: 'Focus: complete next',
            rationale: op.reason,
            preview: 'Complete “${op.title}” (top opportunity right now)',
            entityType: op.entityType ?? 'TASK',
            entityId: op.entityId,
          ),
        ];

      case OrdinIntentKind.none:
        return const [];
    }
  }

  Future<OrdinActionResult> execute(OrdinActionProposal proposal) async {
    if (!proposal.isActionable) {
      return OrdinActionResult(ok: false, message: 'Nothing to execute.');
    }
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();

    try {
      switch (proposal.kind) {
        case OrdinIntentKind.completeTask:
          final id = proposal.entityId;
          if (id == null) {
            return OrdinActionResult(ok: false, message: 'Missing task id.');
          }
          final next = await TaskRepository(_db).complete(id);
          await _record(
            ownerId,
            now,
            eventType: 'ASSISTANT_ACTION_EXECUTED',
            entityType: 'TASK',
            entityId: id,
            metadata:
                '{"action":"completeTask","next":${next == null ? "null" : '"${next.id}"'}}',
            summary: proposal.preview,
          );
          final extra = next == null
              ? ''
              : ' Next occurrence created.';
          return OrdinActionResult(
            ok: true,
            message: 'Done. ${proposal.preview}.$extra',
            entityType: 'TASK',
            entityId: id,
          );

        case OrdinIntentKind.createTask:
          final title = '${proposal.payload['title'] ?? ''}'.trim();
          if (title.isEmpty) {
            return OrdinActionResult(ok: false, message: 'Empty title.');
          }
          final t = await TaskRepository(_db).create(
            title: title,
            status: EntityStatus.inbox,
          );
          await _record(
            ownerId,
            now,
            eventType: 'ASSISTANT_ACTION_EXECUTED',
            entityType: 'TASK',
            entityId: t.id,
            metadata: '{"action":"createTask"}',
            summary: 'Created task via assistant: $title',
          );
          return OrdinActionResult(
            ok: true,
            message: 'Created task “$title”.',
            entityType: 'TASK',
            entityId: t.id,
          );

        case OrdinIntentKind.rescheduleTaskToday:
        case OrdinIntentKind.rescheduleTaskTomorrow:
          final id = proposal.entityId;
          final dayMs = proposal.payload['dayMs'] as int?;
          if (id == null || dayMs == null) {
            return OrdinActionResult(ok: false, message: 'Missing schedule data.');
          }
          final day = DateTime.fromMillisecondsSinceEpoch(dayMs);
          await TaskRepository(_db).reschedule(id, day);
          await _record(
            ownerId,
            now,
            eventType: 'ASSISTANT_ACTION_EXECUTED',
            entityType: 'TASK',
            entityId: id,
            metadata: '{"action":"reschedule","dayMs":$dayMs}',
            summary: proposal.preview,
          );
          return OrdinActionResult(
            ok: true,
            message: proposal.preview,
            entityType: 'TASK',
            entityId: id,
          );

        case OrdinIntentKind.addNote:
          final content = '${proposal.payload['content'] ?? ''}'.trim();
          final note = await NoteRepository(_db).create(content: content);
          await _record(
            ownerId,
            now,
            eventType: 'ASSISTANT_ACTION_EXECUTED',
            entityType: 'NOTE',
            entityId: note.id,
            metadata: '{"action":"addNote"}',
            summary: 'Note via assistant',
          );
          return OrdinActionResult(
            ok: true,
            message: 'Note saved.',
            entityType: 'NOTE',
            entityId: note.id,
          );

        case OrdinIntentKind.createReminder:
          final title = '${proposal.payload['title'] ?? 'Reminder'}';
          final trigger =
              (proposal.payload['triggerAt'] as int?) ?? now + 3600000;
          final id = AppDatabase.newId();
          final db = await _db.database;
          await db.insert('reminders', {
            'id': id,
            'owner_id': ownerId,
            'title': title,
            'trigger_at': trigger,
            'status': 'PENDING',
            'created_at': now,
            'updated_at': now,
          });
          await _record(
            ownerId,
            now,
            eventType: 'ASSISTANT_ACTION_EXECUTED',
            entityType: 'REMINDER',
            entityId: id,
            metadata: '{"action":"createReminder"}',
            summary: 'Reminder: $title',
          );
          return OrdinActionResult(
            ok: true,
            message: 'Reminder set for “$title”.',
            entityType: 'REMINDER',
            entityId: id,
          );

        case OrdinIntentKind.completeHabit:
          final id = proposal.entityId;
          if (id == null) {
            return OrdinActionResult(ok: false, message: 'Missing habit.');
          }
          await HabitRepository(_db).markDoneToday(id);
          await _record(
            ownerId,
            now,
            eventType: 'ASSISTANT_ACTION_EXECUTED',
            entityType: 'HABIT',
            entityId: id,
            metadata: '{"action":"completeHabit"}',
            summary: proposal.preview,
          );
          return OrdinActionResult(
            ok: true,
            message: proposal.preview,
            entityType: 'HABIT',
            entityId: id,
          );

        case OrdinIntentKind.focusNext:
        case OrdinIntentKind.none:
          return OrdinActionResult(ok: false, message: 'No action.');
      }
    } catch (e) {
      return OrdinActionResult(ok: false, message: 'Failed: $e');
    }
  }

  Future<void> recordProposalShown(OrdinActionProposal p) async {
    if (!p.isActionable) return;
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    await _record(
      ownerId,
      now,
      eventType: 'ASSISTANT_ACTION_PROPOSED',
      entityType: p.entityType ?? 'ASSISTANT',
      entityId: p.entityId ?? p.id,
      metadata: '{"kind":"${p.kind.name}"}',
      summary: p.preview,
    );
  }

  Future<void> _record(
    String ownerId,
    int now, {
    required String eventType,
    required String entityType,
    required String entityId,
    String? metadata,
    String? summary,
  }) async {
    final db = await _db.database;
    final row = <String, Object?>{
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'event_type': eventType,
      'entity_type': entityType,
      'entity_id': entityId,
      'occurred_at': now,
      'recorded_at': now,
      'source': EventSource.system,
      'metadata': metadata,
    };
    if (summary != null) {
      try {
        row['summary'] = summary;
        await db.insert('activity_events', row);
        return;
      } catch (_) {
        row.remove('summary');
      }
    }
    await db.insert('activity_events', row);
  }

  OrdinIntentKind _detectIntent(String q, String raw) {
    if (RegExp(r'\b(complete|finish|done with|mark .+ done|i finished)\b')
            .hasMatch(q) ||
        q.startsWith('done ') ||
        q.startsWith('complete ')) {
      return OrdinIntentKind.completeTask;
    }
    if (RegExp(r'\b(add task|create task|new task|todo)\b').hasMatch(q) ||
        (q.startsWith('add ') && !q.contains('note'))) {
      return OrdinIntentKind.createTask;
    }
    if (q.contains('tomorrow') &&
        (q.contains('move') ||
            q.contains('reschedule') ||
            q.contains('push') ||
            q.contains('defer'))) {
      return OrdinIntentKind.rescheduleTaskTomorrow;
    }
    if ((q.contains('today') || q.contains('this evening')) &&
        (q.contains('move') ||
            q.contains('reschedule') ||
            q.contains('schedule'))) {
      return OrdinIntentKind.rescheduleTaskToday;
    }
    if (RegExp(r'\b(add note|write note|journal|note:)\b').hasMatch(q) ||
        q.startsWith('note ')) {
      return OrdinIntentKind.addNote;
    }
    if (RegExp(r'\b(remind me|set reminder|reminder)\b').hasMatch(q)) {
      return OrdinIntentKind.createReminder;
    }
    if (q.contains('habit') &&
        (q.contains('done') || q.contains('complete') || q.contains('check'))) {
      return OrdinIntentKind.completeHabit;
    }
    if (q.contains('do this next') ||
        q.contains('focus next') ||
        q == 'next action') {
      return OrdinIntentKind.focusNext;
    }
    if (q.startsWith('complete ') || q.startsWith('finish ')) {
      return OrdinIntentKind.completeTask;
    }
    return OrdinIntentKind.none;
  }

  Future<Task?> _matchTask(TaskRepository tasks, String raw, String q) async {
    final open = await tasks.listOpen();
    final overdue = await tasks.listOverdue();
    final all = [...overdue, ...open];
    final seen = <String>{};
    final list = <Task>[];
    for (final t in all) {
      if (seen.add(t.id)) list.add(t);
    }
    final quoted = _extractQuoted(raw);
    if (quoted != null) {
      final m = _matchByTitle(
        list.map((t) => (t.id, t.title)).toList(),
        quoted,
        quoted.toLowerCase(),
      );
      if (m != null) return list.firstWhere((t) => t.id == m.$1);
    }
    final stripped = _stripCommand(raw, const [
      'complete',
      'finish',
      'done with',
      'mark done',
      'mark',
      'done',
      'reschedule',
      'move',
      'push',
      'defer',
      'to today',
      'to tomorrow',
      'today',
      'tomorrow',
      'task',
    ]);
    final m = _matchByTitle(
      list.map((t) => (t.id, t.title)).toList(),
      stripped,
      stripped.toLowerCase(),
    );
    if (m == null) return null;
    return list.firstWhere((t) => t.id == m.$1);
  }

  (String, String)? _matchByTitle(
    List<(String, String)> items,
    String raw,
    String q,
  ) {
    if (items.isEmpty || q.trim().isEmpty) return null;
    final needle = q.trim().toLowerCase();
    for (final it in items) {
      if (it.$2.toLowerCase() == needle) return it;
    }
    (String, String)? best;
    var bestScore = 0;
    final tokens =
        needle.split(RegExp(r'\s+')).where((t) => t.length > 2).toList();
    for (final it in items) {
      final title = it.$2.toLowerCase();
      var score = 0;
      if (title.contains(needle) || needle.contains(title)) score += 10;
      for (final t in tokens) {
        if (title.contains(t)) score += 2;
      }
      if (score > bestScore) {
        bestScore = score;
        best = it;
      }
    }
    if (bestScore >= 2) return best;
    return null;
  }

  String? _extractQuoted(String raw) {
    final m = RegExp(r'[“"]([^”"]+)[”"]').firstMatch(raw) ??
        RegExp(r"'([^']+)").firstMatch(raw);
    return m?.group(1)?.trim();
  }

  String _stripCommand(String raw, List<String> cmds) {
    var s = raw.trim();
    final lower = s.toLowerCase();
    for (final c in cmds) {
      if (lower.startsWith(c)) {
        s = s.substring(c.length).trim();
        break;
      }
    }
    s = s.replaceFirst(RegExp(r'^[:\-\s]+'), '');
    return s;
  }
}
