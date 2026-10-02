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
  final _milestones = MilestoneRepository(AppDatabase.instance);
  final _notes = NoteRepository(AppDatabase.instance);
  final _expenses = ExpenseRepository(AppDatabase.instance);
  final _incomeRepo = IncomeRepository(AppDatabase.instance);

  final _input = TextEditingController();
  final _amount = TextEditingController();
  final _search = TextEditingController();

  List<Map<String, Object?>> _people = [];
  List<Map<String, Object?>> _subs = [];
  List<Map<String, Object?>> _debts = [];
  List<Map<String, Object?>> _savings = [];
  List<Map<String, Object?>> _practical = [];
  List<Map<String, Object?>> _docs = [];
  List<Map<String, Object?>> _shop = [];
  List<Map<String, String>> _searchHits = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    _amount.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      // async load below
    });
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
    await _load();
    await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _label('Search'),
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
              title: Text(h['title'] ?? '', style: const TextStyle(color: Colors.white)),
              subtitle: Text(h['type'] ?? '', style: const TextStyle(color: Colors.white38, fontSize: 11)),
            )),
        const Divider(color: Colors.white12),
        _label('Projects'),
        _quickAdd('New project…', (t) async {
          await _projects.create(title: t);
          await _refresh();
        }),
        ...widget.projects.map((p) => ListTile(
              title: Text(p.title, style: const TextStyle(color: Colors.white)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  icon: const Icon(Icons.flag_outlined, color: Colors.amberAccent),
                  onPressed: () async {
                    await _milestones.create(projectId: p.id, title: 'Milestone');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Milestone added')));
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.lightBlueAccent),
                  onPressed: () async {
                    await _projects.complete(p.id);
                    await _refresh();
                  },
                ),
              ]),
            )),
        const Divider(color: Colors.white12),
        _label('People'),
        _quickAdd('Contact name…', (t) async {
          await _ext.addPerson(t);
          await _refresh();
        }),
        ..._people.map((p) => ListTile(
              title: Text('${p['name']}', style: const TextStyle(color: Colors.white)),
            )),
        const Divider(color: Colors.white12),
        _label('Calendar / reminders'),
        _quickAdd('Event title…', (t) async {
          await _ext.addEvent(title: t);
          await _refresh();
        }),
        _quickAdd('Reminder…', (t) async {
          await _ext.addReminder(t);
          await _refresh();
        }),
        const Divider(color: Colors.white12),
        _label('Routines'),
        _quickAdd('New routine…', (t) async {
          await _routines.create(name: t);
          await _refresh();
        }),
        ...widget.routines.map((r) => ListTile(
              title: Text(r.name, style: const TextStyle(color: Colors.white)),
              trailing: IconButton(
                icon: const Icon(Icons.play_arrow, color: Colors.purpleAccent),
                onPressed: () async {
                  await _routines.completeToday(r.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Done: ${r.name}')));
                  }
                },
              ),
            )),
        const Divider(color: Colors.white12),
        _label('Bills'),
        _quickAdd('Bill name…', (t) async {
          await _bills.create(name: t, expectedMajor: 1000, dueInDays: 3);
          await _refresh();
        }),
        ...widget.billOcc.map((o) => ListTile(
              title: Text('Pay: ${o.billName}', style: const TextStyle(color: Colors.orangeAccent)),
              trailing: TextButton(
                onPressed: () async {
                  await _bills.payOccurrence(o);
                  await _refresh();
                },
                child: const Text('Pay'),
              ),
            )),
        const Divider(color: Colors.white12),
        _label('Subscriptions'),
        _quickAdd('Service…', (t) async {
          await _ext.addSubscription(t, 500);
          await _refresh();
        }),
        ..._subs.map((s) => ListTile(
              title: Text('${s['service_name']}', style: const TextStyle(color: Colors.white)),
            )),
        const Divider(color: Colors.white12),
        _label('Debt'),
        _quickAdd('Debt title…', (t) async {
          await _ext.addDebt(title: t, amountMajor: 1000, direction: 'OWED_BY_ME');
          await _refresh();
        }),
        ..._debts.map((d) => ListTile(
              title: Text('${d['title']}', style: const TextStyle(color: Colors.white)),
              trailing: TextButton(
                onPressed: () async {
                  await _ext.payDebt(d['id'] as String, 100);
                  await _refresh();
                },
                child: const Text('Pay 100'),
              ),
            )),
        const Divider(color: Colors.white12),
        _label('Savings'),
        _quickAdd('Goal name…', (t) async {
          await _ext.addSavingsGoal(t, 10000);
          await _refresh();
        }),
        ..._savings.map((s) => ListTile(
              title: Text('${s['name']}', style: const TextStyle(color: Colors.white)),
              trailing: TextButton(
                onPressed: () async {
                  await _ext.contributeSavings(s['id'] as String, 500);
                  await _refresh();
                },
                child: const Text('+500'),
              ),
            )),
        const Divider(color: Colors.white12),
        _label('Money (${Defaults.currency})'),
        Row(children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: _input,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Description',
                hintStyle: TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Color(0xFF1f2937),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: '0.00',
                hintStyle: TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Color(0xFF1f2937),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        ]),
        Row(children: [
          TextButton(
            onPressed: () async {
              final d = _input.text.trim();
              final a = double.tryParse(_amount.text.trim());
              if (d.isEmpty || a == null) return;
              await _expenses.create(description: d, amountMajor: a);
              _input.clear();
              _amount.clear();
              await _refresh();
            },
            child: const Text('Expense'),
          ),
          TextButton(
            onPressed: () async {
              final d = _input.text.trim();
              final a = double.tryParse(_amount.text.trim());
              if (d.isEmpty || a == null) return;
              await _incomeRepo.create(source: d, amountMajor: a);
              _input.clear();
              _amount.clear();
              await _refresh();
            },
            child: const Text('Income'),
          ),
        ]),
        const Divider(color: Colors.white12),
        _label('Practical / docs / shopping'),
        _quickAdd('Practical…', (t) async {
          await _ext.addPractical(t);
          await _refresh();
        }),
        _quickAdd('Document…', (t) async {
          await _ext.addDocument(t);
          await _refresh();
        }),
        _quickAdd('Shopping list…', (t) async {
          await _ext.addShoppingList(t);
          await _refresh();
        }),
        ..._practical.map((p) => ListTile(title: Text('${p['title']}', style: const TextStyle(color: Colors.white)))),
        ..._docs.map((d) => ListTile(title: Text('${d['title']}', style: const TextStyle(color: Colors.white)))),
        ..._shop.map((s) => ListTile(
              title: Text('${s['name']}', style: const TextStyle(color: Colors.white)),
              trailing: IconButton(
                icon: const Icon(Icons.add, color: Colors.white54),
                onPressed: () async {
                  await _ext.addShoppingItem(s['id'] as String, 'Item');
                },
              ),
            )),
        const Divider(color: Colors.white12),
        _label('Notes'),
        _quickAdd('Note…', (t) async {
          await _notes.create(content: t);
          await _refresh();
        }),
        ...widget.notes.map((n) => ListTile(
              title: Text(n.content, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
            )),
      ],
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 6),
        child: Text(t, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
      );

  Widget _quickAdd(String hint, Future<void> Function(String) onAdd) {
    final c = TextEditingController();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: c,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF1f2937),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (v) async {
              if (v.trim().isEmpty) return;
              await onAdd(v.trim());
              c.clear();
            },
          ),
        ),
        IconButton(
          onPressed: () async {
            final v = c.text.trim();
            if (v.isEmpty) return;
            await onAdd(v);
            c.clear();
          },
          icon: const Icon(Icons.add, color: Colors.white70),
        ),
      ]),
    );
  }
}
