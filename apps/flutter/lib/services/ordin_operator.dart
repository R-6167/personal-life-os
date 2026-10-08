import '../data/atomic_write.dart';
import '../data/bill_repository.dart';
import '../data/database.dart';
import '../data/extended_repository.dart';
import '../data/habit_repository.dart';
import '../data/note_repository.dart';
import '../data/task_repository.dart';
import '../domain/enums.dart';
import '../domain/models.dart';
import 'finance_service.dart';
import 'personal_context_engine.dart';

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
  payBill,
  paySubscription,
  pauseSubscription,
  resumeSubscription,
  cancelSubscription,
  createBill,
  createSubscription,
  deferBill,
  cancelBillOccurrence,
}

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
  OrdinActionResult({required this.ok, required this.message, this.entityType, this.entityId});
  final bool ok;
  final String message;
  final String? entityType;
  final String? entityId;
}

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
          return [OrdinActionProposal(id: AppDatabase.newId(), kind: OrdinIntentKind.none, title: 'Could not find that task', rationale: 'No open task matched.', preview: 'Try: complete “task title”')];
        }
        return [OrdinActionProposal(id: AppDatabase.newId(), kind: OrdinIntentKind.completeTask, title: 'Complete task', rationale: '“${match.title}” is open${match.isOverdue ? " and overdue" : ""}.', preview: 'Mark “${match.title}” completed', entityType: 'TASK', entityId: match.id)];

      case OrdinIntentKind.createTask:
        final title = _extractQuoted(raw) ?? _stripCommand(raw, const ['add task', 'create task', 'new task', 'todo', 'add']);
        if (title.length < 2) return const [];
        return [OrdinActionProposal(id: AppDatabase.newId(), kind: OrdinIntentKind.createTask, title: 'Create task', rationale: situation.overdueCount > 0 ? 'You have ${situation.overdueCount} overdue.' : 'Capacity: ${situation.capacityLabel}.', preview: 'Create task “$title”', payload: {'title': title})];

      case OrdinIntentKind.rescheduleTaskToday:
      case OrdinIntentKind.rescheduleTaskTomorrow:
        final match = await _matchTask(tasks, raw, q);
        final day = kind == OrdinIntentKind.rescheduleTaskToday ? DateTime.now() : DateTime.now().add(const Duration(days: 1));
        final label = kind == OrdinIntentKind.rescheduleTaskToday ? 'today' : 'tomorrow';
        Task? t = match;
        if (t == null) {
          final open = await tasks.listOpen();
          final overdue = await tasks.listOverdue();
          t = overdue.isNotEmpty ? overdue.first : (open.isNotEmpty ? open.first : null);
        }
        if (t == null) return const [];
        return [OrdinActionProposal(id: AppDatabase.newId(), kind: kind, title: 'Reschedule to $label', rationale: 'Move work to $label.', preview: 'Move “${t.title}” due date to $label', entityType: 'TASK', entityId: t.id, payload: {'dayMs': DateTime(day.year, day.month, day.day).millisecondsSinceEpoch})];

      case OrdinIntentKind.addNote:
        final body = _extractQuoted(raw) ?? _stripCommand(raw, const ['note', 'add note', 'write', 'journal']);
        if (body.length < 2) return const [];
        return [OrdinActionProposal(id: AppDatabase.newId(), kind: OrdinIntentKind.addNote, title: 'Add note', rationale: 'Capture offline.', preview: body.length > 80 ? '${body.substring(0, 80)}…' : body, payload: {'content': body})];

      case OrdinIntentKind.createReminder:
        final title = _extractQuoted(raw) ?? _stripCommand(raw, const ['remind me', 'reminder', 'set reminder', 'remind']);
        if (title.length < 2) return const [];
        final trigger = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch;
        return [OrdinActionProposal(id: AppDatabase.newId(), kind: OrdinIntentKind.createReminder, title: 'Create reminder', rationale: 'Local reminder in ~1 hour.', preview: 'Remind: “$title”', payload: {'title': title, 'triggerAt': trigger})];

      case OrdinIntentKind.completeHabit:
        final habits = await HabitRepository(_db).listActive();
        final match = _matchByTitle(habits.map((h) => (h.id, h.title)).toList(), raw, q);
        if (match == null) return const [];
        return [OrdinActionProposal(id: AppDatabase.newId(), kind: OrdinIntentKind.completeHabit, title: 'Complete habit', rationale: 'Log today.', preview: 'Mark habit “${match.$2}” done for today', entityType: 'HABIT', entityId: match.$1)];

      case OrdinIntentKind.focusNext:
        final op = situation.opportunities.isNotEmpty ? situation.opportunities.first : null;
        if (op == null || op.entityId == null) {
          return [OrdinActionProposal(id: AppDatabase.newId(), kind: OrdinIntentKind.none, title: 'No clear next action', rationale: situation.capacityLabel, preview: 'Try Planning → Build My Day')];
        }
        return [OrdinActionProposal(id: AppDatabase.newId(), kind: OrdinIntentKind.completeTask, title: 'Focus: complete next', rationale: op.reason, preview: 'Complete “${op.title}”', entityType: op.entityType ?? 'TASK', entityId: op.entityId)];

      case OrdinIntentKind.payBill:
        final bills = BillRepository(_db);
        await bills.refreshOccurrenceStatuses();
        final open = await bills.listOpenOccurrences();
        if (open.isEmpty) {
          return [OrdinActionProposal(id: AppDatabase.newId(), kind: OrdinIntentKind.none, title: 'No open bills', rationale: 'Nothing due.', preview: 'All clear')];
        }
        final named = _matchByTitle(open.map((o) => (o.id, o.billName ?? 'Bill')).toList(), raw, q);
        final occ = named == null ? open.first : open.firstWhere((o) => o.id == named.$1, orElse: () => open.first);
        final amt = occ.expectedAmountMinor ?? 0;
        final due = DateTime.fromMillisecondsSinceEpoch(occ.dueAt);
        final dueStr = '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}';
        return [OrdinActionProposal(id: AppDatabase.newId(), kind: OrdinIntentKind.payBill, title: 'Pay bill', rationale: '“${occ.billName ?? 'Bill'}” due $dueStr.', preview: 'Record payment of ${(amt / 100).toStringAsFixed(2)} for “${occ.billName ?? 'Bill'}”', entityType: 'BILL_OCCURRENCE', entityId: occ.id, payload: {'billId': occ.billId, 'billName': occ.billName, 'amountMinor': amt, 'dueAt': occ.dueAt})];

      case OrdinIntentKind.paySubscription:
      case OrdinIntentKind.pauseSubscription:
      case OrdinIntentKind.resumeSubscription:
      case OrdinIntentKind.cancelSubscription:
        final ext = ExtendedRepository(_db);
        final subs = await ext.listSubscriptions(includePaused: true);
        final pool = kind == OrdinIntentKind.resumeSubscription
            ? subs.where((s) => '${s['status']}' == 'PAUSED').toList()
            : (kind == OrdinIntentKind.pauseSubscription || kind == OrdinIntentKind.paySubscription)
                ? subs.where((s) => '${s['status']}' == 'ACTIVE').toList()
                : subs;
        if (pool.isEmpty) {
          return [OrdinActionProposal(id: AppDatabase.newId(), kind: OrdinIntentKind.none, title: 'No matching subscription', rationale: 'Nothing available.', preview: 'Check Finance → Subscriptions')];
        }
        final named = _matchByTitle(pool.map((s) => ('${s['id']}', '${s['service_name'] ?? s['name'] ?? 'Subscription'}')).toList(), raw, q);
        final row = named == null ? pool.first : pool.firstWhere((s) => '${s['id']}' == named.$1, orElse: () => pool.first);
        final sid = '${row['id']}';
        final name = '${row['service_name'] ?? row['name'] ?? 'Subscription'}';
        final amount = (row['amount_minor'] as int?) ?? 0;
        if (kind == OrdinIntentKind.paySubscription) {
          return [OrdinActionProposal(id: AppDatabase.newId(), kind: OrdinIntentKind.paySubscription, title: 'Pay subscription', rationale: 'Renew “$name”.', preview: 'Pay ${(amount / 100).toStringAsFixed(2)} · renew “$name”', entityType: 'SUBSCRIPTION', entityId: sid, payload: {'amountMinor': amount, 'name': name})];
        }
        if (kind == OrdinIntentKind.pauseSubscription) {
          return [OrdinActionProposal(id: AppDatabase.newId(), kind: OrdinIntentKind.pauseSubscription, title: 'Pause subscription', rationale: 'Pause “$name”.', preview: 'Pause “$name”', entityType: 'SUBSCRIPTION', entityId: sid, payload: {'name': name})];
        }
        if (kind == OrdinIntentKind.resumeSubscription) {
          return [OrdinActionProposal(id: AppDatabase.newId(), kind: OrdinIntentKind.resumeSubscription, title: 'Resume subscription', rationale: 'Resume “$name”.', preview: 'Resume “$name”', entityType: 'SUBSCRIPTION', entityId: sid, payload: {'name': name})];
        }
        return [OrdinActionProposal(id: AppDatabase.newId(), kind: OrdinIntentKind.cancelSubscription, title: 'Cancel subscription', rationale: 'Stop tracking “$name”.', preview: 'Cancel “$name”', entityType: 'SUBSCRIPTION', entityId: sid, payload: {'name': name})];

      case OrdinIntentKind.createBill:
        final stripped = _stripCommand(raw, const ['add bill', 'create bill', 'new bill', 'bill']);
        final parsed = _parseNameAndAmount(stripped);
        if (parsed.$1.length < 2) return const [];
        final amt = parsed.$2;
        return [OrdinActionProposal(id: AppDatabase.newId(), kind: OrdinIntentKind.createBill, title: 'Create bill', rationale: amt == null ? 'Track “${parsed.$1}” monthly (due in 7 days).' : 'Track “${parsed.$1}” at ${amt.toStringAsFixed(2)} monthly.', preview: amt == null ? 'Create bill “${parsed.$1}”' : 'Create bill “${parsed.$1}” · ${amt.toStringAsFixed(2)}', payload: {'name': parsed.$1, if (amt != null) 'amountMajor': amt})];

      case OrdinIntentKind.createSubscription:
        final stripped = _stripCommand(raw, const ['add subscription', 'create subscription', 'new subscription', 'subscribe to', 'subscription']);
        final parsed = _parseNameAndAmount(stripped);
        if (parsed.$1.length < 2) return const [];
        final amt = parsed.$2 ?? 0.0;
        return [OrdinActionProposal(id: AppDatabase.newId(), kind: OrdinIntentKind.createSubscription, title: 'Create subscription', rationale: 'Track “${parsed.$1}”${amt > 0 ? " at ${amt.toStringAsFixed(2)}/month" : ""}.', preview: amt > 0 ? 'Add subscription “${parsed.$1}” · ${amt.toStringAsFixed(2)}' : 'Add subscription “${parsed.$1}”', payload: {'name': parsed.$1, 'amountMajor': amt})];

      case OrdinIntentKind.deferBill:
      case OrdinIntentKind.cancelBillOccurrence:
        final bills = BillRepository(_db);
        await bills.refreshOccurrenceStatuses();
        final open = await bills.listOpenOccurrences();
        if (open.isEmpty) {
          return [OrdinActionProposal(id: AppDatabase.newId(), kind: OrdinIntentKind.none, title: 'No open bills', rationale: 'Nothing to change.', preview: 'Bill list is clear')];
        }
        final named = _matchByTitle(open.map((o) => (o.id, o.billName ?? 'Bill')).toList(), raw, q);
        final occ = named == null ? open.first : open.firstWhere((o) => o.id == named.$1, orElse: () => open.first);
        if (kind == OrdinIntentKind.deferBill) {
          final newDue = DateTime.fromMillisecondsSinceEpoch(occ.dueAt).add(const Duration(days: 7));
          final dueStr = '${newDue.year}-${newDue.month.toString().padLeft(2, '0')}-${newDue.day.toString().padLeft(2, '0')}';
          return [OrdinActionProposal(id: AppDatabase.newId(), kind: OrdinIntentKind.deferBill, title: 'Defer bill', rationale: 'Push “${occ.billName ?? 'Bill'}” one week.', preview: 'Defer “${occ.billName ?? 'Bill'}” to $dueStr', entityType: 'BILL_OCCURRENCE', entityId: occ.id, payload: {'billId': occ.billId, 'newDueAt': newDue.millisecondsSinceEpoch, 'billName': occ.billName})];
        }
        return [OrdinActionProposal(id: AppDatabase.newId(), kind: OrdinIntentKind.cancelBillOccurrence, title: 'Cancel bill occurrence', rationale: 'Drop this cycle for “${occ.billName ?? 'Bill'}”.', preview: 'Cancel occurrence of “${occ.billName ?? 'Bill'}”', entityType: 'BILL_OCCURRENCE', entityId: occ.id, payload: {'billId': occ.billId, 'billName': occ.billName})];

      case OrdinIntentKind.none:
        return const [];
    }
  }

  Future<OrdinActionResult> execute(OrdinActionProposal proposal) async =>
      OrdinActionExecutor(db: _db, operator: this).execute(proposal);

  Future<OrdinActionResult> _executeInternal(OrdinActionProposal proposal) async {
    if (!proposal.isActionable) return OrdinActionResult(ok: false, message: 'Nothing to execute.');
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    try {
      switch (proposal.kind) {
        case OrdinIntentKind.completeTask:
          final id = proposal.entityId;
          if (id == null) return OrdinActionResult(ok: false, message: 'Missing task id.');
          final next = await TaskRepository(_db).complete(id);
          await _record(ownerId, now, eventType: 'ASSISTANT_ACTION_EXECUTED', entityType: 'TASK', entityId: id, metadata: '{"action":"completeTask"}', summary: proposal.preview);
          return OrdinActionResult(ok: true, message: 'Done. ${proposal.preview}${next == null ? '' : ' Next occurrence created.'}', entityType: 'TASK', entityId: id);

        case OrdinIntentKind.createTask:
          final title = '${proposal.payload['title'] ?? ''}'.trim();
          if (title.isEmpty) return OrdinActionResult(ok: false, message: 'Empty title.');
          final t = await TaskRepository(_db).create(title: title, status: EntityStatus.inbox);
          await _record(ownerId, now, eventType: 'ASSISTANT_ACTION_EXECUTED', entityType: 'TASK', entityId: t.id, metadata: '{"action":"createTask"}', summary: proposal.preview);
          return OrdinActionResult(ok: true, message: 'Created task “$title”.', entityType: 'TASK', entityId: t.id);

        case OrdinIntentKind.rescheduleTaskToday:
        case OrdinIntentKind.rescheduleTaskTomorrow:
          final id = proposal.entityId;
          final dayMs = proposal.payload['dayMs'] as int?;
          if (id == null || dayMs == null) return OrdinActionResult(ok: false, message: 'Missing schedule data.');
          final due = DateTime.fromMillisecondsSinceEpoch(dayMs);
          final dueAt = DateTime(due.year, due.month, due.day, 23, 59).millisecondsSinceEpoch;
          await AtomicWrite.run(
            db: _db,
            state: (txn) async {
              await txn.update('tasks', {'due_at': dueAt, 'updated_at': now}, where: 'id = ?', whereArgs: [id]);
            },
            eventType: 'ASSISTANT_ACTION_EXECUTED',
            entityType: 'TASK',
            entityId: id,
            source: EventSource.system,
            metadata: '{"action":"reschedule"}',
            occurredAt: now,
          );
          return OrdinActionResult(ok: true, message: proposal.preview, entityType: 'TASK', entityId: id);

        case OrdinIntentKind.addNote:
          final content = '${proposal.payload['content'] ?? ''}'.trim();
          final note = await NoteRepository(_db).create(content: content);
          await _record(ownerId, now, eventType: 'ASSISTANT_ACTION_EXECUTED', entityType: 'NOTE', entityId: note.id, metadata: '{"action":"addNote"}', summary: 'Note via assistant');
          return OrdinActionResult(ok: true, message: 'Note saved.', entityType: 'NOTE', entityId: note.id);

        case OrdinIntentKind.createReminder:
          final title = '${proposal.payload['title'] ?? 'Reminder'}';
          final trigger = (proposal.payload['triggerAt'] as int?) ?? now + 3600000;
          final id = AppDatabase.newId();
          await AtomicWrite.run(
            db: _db,
            state: (txn) async {
              await txn.insert('reminders', {'id': id, 'owner_id': ownerId, 'title': title, 'trigger_at': trigger, 'status': 'PENDING', 'created_at': now, 'updated_at': now});
            },
            eventType: 'ASSISTANT_ACTION_EXECUTED',
            entityType: 'REMINDER',
            entityId: id,
            source: EventSource.system,
            metadata: '{"action":"createReminder"}',
            occurredAt: now,
          );
          return OrdinActionResult(ok: true, message: 'Reminder set for “$title”.', entityType: 'REMINDER', entityId: id);

        case OrdinIntentKind.completeHabit:
          final id = proposal.entityId;
          if (id == null) return OrdinActionResult(ok: false, message: 'Missing habit.');
          await HabitRepository(_db).markDoneToday(id);
          await _record(ownerId, now, eventType: 'ASSISTANT_ACTION_EXECUTED', entityType: 'HABIT', entityId: id, metadata: '{"action":"completeHabit"}', summary: proposal.preview);
          return OrdinActionResult(ok: true, message: proposal.preview, entityType: 'HABIT', entityId: id);

        case OrdinIntentKind.payBill:
          final occId = proposal.entityId;
          if (occId == null) return OrdinActionResult(ok: false, message: 'Missing bill occurrence.');
          final bills = BillRepository(_db);
          await bills.refreshOccurrenceStatuses();
          final open = await bills.listOpenOccurrences();
          BillOccurrence? occ;
          for (final o in open) { if (o.id == occId) { occ = o; break; } }
          if (occ == null) {
            final billId = '${proposal.payload['billId'] ?? ''}';
            if (billId.isEmpty) return OrdinActionResult(ok: false, message: 'Bill occurrence not found.');
            occ = BillOccurrence(id: occId, billId: billId, dueAt: proposal.payload['dueAt'] as int? ?? now, expectedAmountMinor: proposal.payload['amountMinor'] as int?, status: 'DUE', billName: proposal.payload['billName'] as String?);
          }
          await bills.payOccurrence(occ);
          await _record(ownerId, now, eventType: 'ASSISTANT_ACTION_EXECUTED', entityType: 'BILL', entityId: occ.billId, metadata: '{"action":"payBill"}', summary: proposal.preview);
          return OrdinActionResult(ok: true, message: proposal.preview, entityType: 'BILL', entityId: occ.billId);

        case OrdinIntentKind.paySubscription:
          final sid = proposal.entityId;
          if (sid == null) return OrdinActionResult(ok: false, message: 'Missing subscription.');
          final amountMinor = proposal.payload['amountMinor'] as int?;
          await FinanceService().paySubscription(subscriptionId: sid, amountMajor: amountMinor == null ? null : amountMinor / 100.0);
          await _record(ownerId, now, eventType: 'ASSISTANT_ACTION_EXECUTED', entityType: 'SUBSCRIPTION', entityId: sid, metadata: '{"action":"paySubscription"}', summary: proposal.preview);
          return OrdinActionResult(ok: true, message: proposal.preview, entityType: 'SUBSCRIPTION', entityId: sid);

        case OrdinIntentKind.pauseSubscription:
        case OrdinIntentKind.resumeSubscription:
        case OrdinIntentKind.cancelSubscription:
          final sid = proposal.entityId;
          if (sid == null) return OrdinActionResult(ok: false, message: 'Missing subscription.');
          final ext = ExtendedRepository(_db);
          if (proposal.kind == OrdinIntentKind.pauseSubscription) {
            await ext.pauseSubscription(sid);
          } else if (proposal.kind == OrdinIntentKind.resumeSubscription) {
            await ext.resumeSubscription(sid);
          } else {
            await ext.cancelSubscription(sid);
          }
          await _record(ownerId, now, eventType: 'ASSISTANT_ACTION_EXECUTED', entityType: 'SUBSCRIPTION', entityId: sid, metadata: '{"action":"${proposal.kind.name}"}', summary: proposal.preview);
          return OrdinActionResult(ok: true, message: proposal.preview, entityType: 'SUBSCRIPTION', entityId: sid);

        case OrdinIntentKind.createBill:
          final name = '${proposal.payload['name'] ?? ''}'.trim();
          if (name.isEmpty) return OrdinActionResult(ok: false, message: 'Missing bill name.');
          final amountMajor = proposal.payload['amountMajor'] as double?;
          final bill = await BillRepository(_db).create(name: name, expectedMajor: amountMajor, dueInDays: 7, frequency: 'MONTHLY');
          await _record(ownerId, now, eventType: 'ASSISTANT_ACTION_EXECUTED', entityType: 'BILL', entityId: bill.id, metadata: '{"action":"createBill"}', summary: proposal.preview);
          return OrdinActionResult(ok: true, message: proposal.preview, entityType: 'BILL', entityId: bill.id);

        case OrdinIntentKind.createSubscription:
          final name = '${proposal.payload['name'] ?? ''}'.trim();
          if (name.isEmpty) return OrdinActionResult(ok: false, message: 'Missing name.');
          final amountMajor = (proposal.payload['amountMajor'] as num?)?.toDouble() ?? 0;
          final id = await FinanceService().createSubscription(name: name, amountMajor: amountMajor);
          await _record(ownerId, now, eventType: 'ASSISTANT_ACTION_EXECUTED', entityType: 'SUBSCRIPTION', entityId: id, metadata: '{"action":"createSubscription"}', summary: proposal.preview);
          return OrdinActionResult(ok: true, message: proposal.preview, entityType: 'SUBSCRIPTION', entityId: id);

        case OrdinIntentKind.deferBill:
          final occId = proposal.entityId;
          final newDue = proposal.payload['newDueAt'] as int?;
          if (occId == null || newDue == null) return OrdinActionResult(ok: false, message: 'Missing defer data.');
          final db = await _db.database;
          await db.update('bill_occurrences', {'due_at': newDue, 'status': 'UPCOMING', 'updated_at': now}, where: 'id = ?', whereArgs: [occId]);
          final billId = '${proposal.payload['billId'] ?? ''}';
          if (billId.isNotEmpty) {
            await db.update('bills', {'next_due_at': newDue, 'updated_at': now}, where: 'id = ?', whereArgs: [billId]);
          }
          await _record(ownerId, now, eventType: 'ASSISTANT_ACTION_EXECUTED', entityType: 'BILL_OCCURRENCE', entityId: occId, metadata: '{"action":"deferBill"}', summary: proposal.preview);
          return OrdinActionResult(ok: true, message: proposal.preview, entityType: 'BILL_OCCURRENCE', entityId: occId);

        case OrdinIntentKind.cancelBillOccurrence:
          final occId = proposal.entityId;
          if (occId == null) return OrdinActionResult(ok: false, message: 'Missing occurrence.');
          await (await _db.database).update('bill_occurrences', {'status': 'CANCELLED', 'updated_at': now}, where: 'id = ?', whereArgs: [occId]);
          await _record(ownerId, now, eventType: 'ASSISTANT_ACTION_EXECUTED', entityType: 'BILL_OCCURRENCE', entityId: occId, metadata: '{"action":"cancelBillOccurrence"}', summary: proposal.preview);
          return OrdinActionResult(ok: true, message: proposal.preview, entityType: 'BILL_OCCURRENCE', entityId: occId);

        case OrdinIntentKind.focusNext:
        case OrdinIntentKind.none:
          return OrdinActionResult(ok: false, message: 'No action.');
      }
    } catch (e) {
      return OrdinActionResult(ok: false, message: 'Failed: $e');
    }
  }

}

/// Central approval/execution boundary for assistant actions.
///
/// It validates ownership and required identifiers before execution. The
/// operator's direct SQL mutations use AtomicWrite, so their assistant audit
/// event commits with the state change.
class OrdinActionExecutor {
  OrdinActionExecutor({required AppDatabase db, required OrdinOperator operator})
      : _db = db,
        _operator = operator;

  final AppDatabase _db;
  final OrdinOperator _operator;

  Future<OrdinActionResult> execute(OrdinActionProposal proposal) async {
    final validation = await _validate(proposal);
    if (validation != null) return validation;
    try {
      return await _operator._executeInternal(proposal);
    } catch (e) {
      return OrdinActionResult(ok: false, message: 'Failed: $e');
    }
  }

  Future<OrdinActionResult?> _validate(OrdinActionProposal proposal) async {
    if (!proposal.isActionable) {
      return OrdinActionResult(ok: false, message: 'Nothing to execute.');
    }
    final ownerId = await _db.requireOwnerId();
    switch (proposal.kind) {
      case OrdinIntentKind.completeTask:
      case OrdinIntentKind.rescheduleTaskToday:
      case OrdinIntentKind.rescheduleTaskTomorrow:
        return _requireOwned(proposal.entityId, 'tasks', ownerId, 'Task');
      case OrdinIntentKind.completeHabit:
        return _requireOwned(proposal.entityId, 'habits', ownerId, 'Habit');
      case OrdinIntentKind.payBill:
      case OrdinIntentKind.deferBill:
      case OrdinIntentKind.cancelBillOccurrence:
        final id = proposal.entityId;
        if (id == null) return OrdinActionResult(ok: false, message: 'Missing bill occurrence.');
        final rows = await (await _db.database).rawQuery(
          'SELECT o.id FROM bill_occurrences o JOIN bills b ON b.id = o.bill_id WHERE o.id = ? AND b.owner_id = ? LIMIT 1',
          [id, ownerId],
        );
        return rows.isEmpty
            ? OrdinActionResult(ok: false, message: 'Bill occurrence is missing or not owned by the current user.')
            : null;
      case OrdinIntentKind.paySubscription:
      case OrdinIntentKind.pauseSubscription:
      case OrdinIntentKind.resumeSubscription:
      case OrdinIntentKind.cancelSubscription:
        return _requireOwned(proposal.entityId, 'subscriptions', ownerId, 'Subscription');
      case OrdinIntentKind.addNote:
      case OrdinIntentKind.createTask:
      case OrdinIntentKind.createReminder:
      case OrdinIntentKind.createBill:
      case OrdinIntentKind.createSubscription:
      case OrdinIntentKind.focusNext:
      case OrdinIntentKind.none:
        return null;
    }
  }

  Future<OrdinActionResult?> _requireOwned(
    String? id,
    String table,
    String ownerId,
    String label,
  ) async {
    if (id == null || id.isEmpty) {
      return OrdinActionResult(ok: false, message: 'Missing $label id.');
    }
    final rows = await (await _db.database).query(
      table,
      columns: ['id'],
      where: 'id = ? AND owner_id = ?',
      whereArgs: [id, ownerId],
      limit: 1,
    );
    return rows.isEmpty
        ? OrdinActionResult(ok: false, message: '$label is missing or not owned by the current user.')
        : null;
  }

  Future<void> recordProposalShown(OrdinActionProposal p) async {
    if (!p.isActionable) return;
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    await _record(ownerId, now, eventType: 'ASSISTANT_ACTION_PROPOSED', entityType: p.entityType ?? 'ASSISTANT', entityId: p.entityId ?? p.id, metadata: '{"kind":"${p.kind.name}"}', summary: p.preview);
  }

  Future<void> _record(String ownerId, int now, {required String eventType, required String entityType, required String entityId, String? metadata, String? summary}) async {
    final db = await _db.database;
    final row = <String, Object?>{'id': AppDatabase.newId(), 'owner_id': ownerId, 'event_type': eventType, 'entity_type': entityType, 'entity_id': entityId, 'occurred_at': now, 'recorded_at': now, 'source': EventSource.system, 'metadata': metadata};
    if (summary != null) {
      try { row['summary'] = summary; await db.insert('activity_events', row); return; } catch (_) { row.remove('summary'); }
    }
    await db.insert('activity_events', row);
  }

  OrdinIntentKind _detectIntent(String q, String raw) {
    if (RegExp(r'\b(complete|finish|done with|mark .+ done|i finished)\b').hasMatch(q) || q.startsWith('done ') || q.startsWith('complete ')) return OrdinIntentKind.completeTask;
    if (RegExp(r'\b(add task|create task|new task|todo)\b').hasMatch(q) || (q.startsWith('add ') && !q.contains('note') && !q.contains('bill') && !q.contains('subscription'))) return OrdinIntentKind.createTask;
    if (q.contains('tomorrow') && (q.contains('move') || q.contains('reschedule') || q.contains('push') || q.contains('defer'))) return OrdinIntentKind.rescheduleTaskTomorrow;
    if ((q.contains('today') || q.contains('this evening')) && (q.contains('move') || q.contains('reschedule') || q.contains('schedule'))) return OrdinIntentKind.rescheduleTaskToday;
    if (RegExp(r'\b(add note|write note|journal|note:)\b').hasMatch(q) || q.startsWith('note ')) return OrdinIntentKind.addNote;
    if (RegExp(r'\b(remind me|set reminder|reminder)\b').hasMatch(q)) return OrdinIntentKind.createReminder;
    if (q.contains('habit') && (q.contains('done') || q.contains('complete') || q.contains('check'))) return OrdinIntentKind.completeHabit;
    if (q.contains('do this next') || q.contains('focus next') || q == 'next action') return OrdinIntentKind.focusNext;
    if (RegExp(r'\b(add bill|create bill|new bill)\b').hasMatch(q)) return OrdinIntentKind.createBill;
    if (RegExp(r'\b(add subscription|create subscription|new subscription|subscribe to)\b').hasMatch(q)) return OrdinIntentKind.createSubscription;
    if (RegExp(r'\b(defer bill|snooze bill|push bill|postpone bill)\b').hasMatch(q) || (q.contains('defer') && q.contains('bill')) || (q.contains('snooze') && q.contains('bill'))) return OrdinIntentKind.deferBill;
    if (RegExp(r'\b(skip bill|cancel bill occurrence|cancel this bill)\b').hasMatch(q) || (q.contains('skip') && q.contains('bill'))) return OrdinIntentKind.cancelBillOccurrence;
    if (RegExp(r'\b(pay bill|pay the bill|settle bill|bill paid)\b').hasMatch(q) || (q.contains('pay') && q.contains('bill'))) return OrdinIntentKind.payBill;
    if (RegExp(r'\b(pay subscription|renew subscription|subscription payment)\b').hasMatch(q) || (q.contains('pay') && q.contains('subscription')) || (q.contains('renew') && q.contains('subscription'))) return OrdinIntentKind.paySubscription;
    if (RegExp(r'\b(pause subscription|pause sub)\b').hasMatch(q) || (q.startsWith('pause ') && (q.contains('sub') || q.contains('subscription')))) return OrdinIntentKind.pauseSubscription;
    if (RegExp(r'\b(resume subscription|unpause)\b').hasMatch(q) || (q.startsWith('resume ') && (q.contains('sub') || q.contains('subscription')))) return OrdinIntentKind.resumeSubscription;
    if (RegExp(r'\b(cancel subscription|cancel sub)\b').hasMatch(q) || (q.startsWith('cancel ') && (q.contains('sub') || q.contains('subscription')))) return OrdinIntentKind.cancelSubscription;
    if (q.startsWith('complete ') || q.startsWith('finish ')) return OrdinIntentKind.completeTask;
    return OrdinIntentKind.none;
  }

  Future<Task?> _matchTask(TaskRepository tasks, String raw, String q) async {
    final open = await tasks.listOpen();
    final overdue = await tasks.listOverdue();
    final all = [...overdue, ...open];
    final seen = <String>{};
    final list = <Task>[];
    for (final t in all) { if (seen.add(t.id)) list.add(t); }
    final quoted = _extractQuoted(raw);
    if (quoted != null) {
      final m = _matchByTitle(list.map((t) => (t.id, t.title)).toList(), quoted, quoted.toLowerCase());
      if (m != null) return list.firstWhere((t) => t.id == m.$1);
    }
    final stripped = _stripCommand(raw, const ['complete', 'finish', 'done with', 'mark done', 'mark', 'done', 'reschedule', 'move', 'push', 'defer', 'to today', 'to tomorrow', 'today', 'tomorrow', 'task']);
    final m = _matchByTitle(list.map((t) => (t.id, t.title)).toList(), stripped, stripped.toLowerCase());
    if (m == null) return null;
    return list.firstWhere((t) => t.id == m.$1);
  }

  (String, String)? _matchByTitle(List<(String, String)> items, String raw, String q) {
    if (items.isEmpty || q.trim().isEmpty) return null;
    final needle = q.trim().toLowerCase();
    for (final it in items) { if (it.$2.toLowerCase() == needle) return it; }
    (String, String)? best;
    var bestScore = 0;
    final tokens = needle.split(RegExp(r'\s+')).where((t) => t.length > 2).toList();
    for (final it in items) {
      final title = it.$2.toLowerCase();
      var score = 0;
      if (title.contains(needle) || needle.contains(title)) score += 10;
      for (final t in tokens) { if (title.contains(t)) score += 2; }
      if (score > bestScore) { bestScore = score; best = it; }
    }
    if (bestScore >= 2) return best;
    return null;
  }

  String? _extractQuoted(String raw) {
    final m = RegExp(r'[“"]([^”"]+)[”"]').firstMatch(raw) ?? RegExp(r"'([^']+)").firstMatch(raw);
    return m?.group(1)?.trim();
  }

  (String, double?) _parseNameAndAmount(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return ('', null);
    final m = RegExp(r'^(.*?)(?:\s+)(\d+(?:[.,]\d{1,2})?)\s*$').firstMatch(s);
    if (m != null) {
      final name = (m.group(1) ?? '').trim();
      final numStr = (m.group(2) ?? '').replaceAll(',', '');
      final amt = double.tryParse(numStr);
      if (name.isNotEmpty) return (name, amt);
    }
    return (s, null);
  }

  String _stripCommand(String raw, List<String> cmds) {
    var s = raw.trim();
    final lower = s.toLowerCase();
    for (final c in cmds) {
      if (lower.startsWith(c)) { s = s.substring(c.length).trim(); break; }
    }
    return s.replaceFirst(RegExp(r'^[:\-\s]+'), '');
  }
}
