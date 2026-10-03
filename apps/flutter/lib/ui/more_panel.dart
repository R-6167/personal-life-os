import 'package:flutter/material.dart';

import '../data/bill_repository.dart';
import '../data/database.dart';
import '../data/expense_repository.dart';
import '../data/extended_repository.dart';
import '../data/income_repository.dart';
import '../data/milestone_repository.dart';
import '../data/note_repository.dart';
import '../data/project_repository.dart';
import '../data/routine_repository.dart';
import '../domain/enums.dart';
import '../domain/models.dart';
import '../services/user_prefs.dart';

class MorePanel extends StatefulWidget {
  const MorePanel({
    super.key,
    required this.onChanged,
    required this.projects,
    required this.routines,
    required this.bills,
    required this.billOcc,
    required this.notes,
    required this.expenses,
    required this.income,
  });

  final Future<void> Function() onChanged;
  final List<Project> projects;
  final List<Routine> routines;
  final List<Bill> bills;
  final List<BillOccurrence> billOcc;
  final List<Note> notes;
  final List<Expense> expenses;
  final List<Income> income;

  @override
  State<MorePanel> createState() => _MorePanelState();
}

class _MorePanelState extends State<MorePanel> {
  final _ext = ExtendedRepository(AppDatabase.instance);
  final _projects = ProjectRepository(AppDatabase.instance);
  final _routines = RoutineRepository(AppDatabase.instance);
  final _bills = BillRepository(AppDatabase.instance);
  final _notes = NoteRepository(AppDatabase.instance);
  final _expenses = ExpenseRepository(AppDatabase.instance);
  final _incomeRepo = IncomeRepository(AppDatabase.instance);

  final _search = TextEditingController();
  List<Map<String, Object?>> _people = [];
  List<Map<String, Object?>> _subs = [];
  List<Map<String, Object?>> _debts = [];
  List<Map<String, Object?>> _savings = [];
  List<Map<String, Object?>> _practical = [];
  List<Map<String, Object?>> _docs = [];
  List<Map<String, Object?>> _shop = [];
  List<Map<String, Object?>> _searchHits = [];

  @override
  void initState() {
    super.initState();
    _loadExtra();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadExtra() async {
    final people = await _ext.listPeople();
    final subs = await _ext.listSubscriptions();
    final debts = await _ext.listDebts();
    final savings = await _ext.listSavings();
    final practical = await _ext.listPractical();
    final docs = await _ext.listDocuments();
    final shop = await _ext.listShoppingLists();
    if (!mounted) return;
    setState(() {
      _people = people;
      _subs = subs;
      _debts = debts;
      _savings = savings;
      _practical = practical;
      _docs = docs;
      _shop = shop;
    });
  }

  Future<void> _refresh() async {
    await _loadExtra();
    await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: _search,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Search tasks, bills, people…',
                hintStyle: TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Color(0xFF1f2937),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (q) async {
                final hits = await _ext.search(q);
                setState(() => _searchHits = hits);
              },
            ),
          ),
          IconButton(
            onPressed: () async {
              final hits = await _ext.search(_search.text);
              setState(() => _searchHits = hits);
            },
            icon: const Icon(Icons.search, color: Colors.white70),
          ),
        ]),
        ..._searchHits.map((h) => ListTile(
              dense: true,
              title: Text(
                h['label']?.toString() ?? h['title']?.toString() ?? '',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                h['kind']?.toString() ?? h['type']?.toString() ?? '',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            )),
        const Divider(color: Colors.white12),
        _label('Projects (${widget.projects.length})'),
        ...widget.projects.take(8).map((p) => ListTile(
              dense: true,
              title: Text(p.title, style: const TextStyle(color: Colors.white)),
              subtitle: Text(p.status, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            )),
        _label('Routines (${widget.routines.length})'),
        ...widget.routines.take(6).map((r) => ListTile(
              dense: true,
              title: Text(r.name, style: const TextStyle(color: Colors.white)),
            )),
        _label('Bills open (${widget.billOcc.length})'),
        ...widget.billOcc.take(6).map((o) => ListTile(
              dense: true,
              title: Text(o.billName ?? 'Bill', style: const TextStyle(color: Colors.white)),
            )),
        _label('People (${_people.length})'),
        ..._people.take(6).map((p) => ListTile(
              dense: true,
              title: Text('${p['name'] ?? ''}', style: const TextStyle(color: Colors.white)),
            )),
        _label('Subscriptions (${_subs.length})'),
        ..._subs.take(6).map((s) => ListTile(
              dense: true,
              title: Text('${s['name'] ?? ''}', style: const TextStyle(color: Colors.white)),
            )),
        _label('Debts (${_debts.length})'),
        ..._debts.take(6).map((d) => ListTile(
              dense: true,
              title: Text('${d['title'] ?? d['counterparty'] ?? ''}', style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                '${d['direction']} · ${UserPrefs.instance.currency} ${((d['remaining_amount_minor'] as int?) ?? 0) / 100}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            )),
        _label('Savings (${_savings.length})'),
        ..._savings.take(6).map((s) => ListTile(
              dense: true,
              title: Text('${s['name'] ?? ''}', style: const TextStyle(color: Colors.white)),
            )),
        _label('Notes (${widget.notes.length})'),
        ...widget.notes.take(6).map((n) => ListTile(
              dense: true,
              title: Text(n.title ?? n.content, style: const TextStyle(color: Colors.white)),
            )),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: () async {
                final c = TextEditingController();
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Person'),
                    content: TextField(controller: c, autofocus: true),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
                    ],
                  ),
                );
                if (ok == true && c.text.trim().isNotEmpty) {
                  await _ext.addPerson(c.text.trim());
                  await _refresh();
                }
              },
              child: const Text('+ Person'),
            ),
            FilledButton.tonal(
              onPressed: () async {
                final c = TextEditingController();
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Event'),
                    content: TextField(controller: c, autofocus: true),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
                    ],
                  ),
                );
                if (ok == true && c.text.trim().isNotEmpty) {
                  await _ext.addEvent(title: c.text.trim());
                  await _refresh();
                }
              },
              child: const Text('+ Event'),
            ),
            FilledButton.tonal(
              onPressed: () async {
                final c = TextEditingController();
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Reminder'),
                    content: TextField(controller: c, autofocus: true),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
                    ],
                  ),
                );
                if (ok == true && c.text.trim().isNotEmpty) {
                  await _ext.addReminder(c.text.trim());
                  await _refresh();
                }
              },
              child: const Text('+ Reminder'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(t, style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w600)),
      );
}
