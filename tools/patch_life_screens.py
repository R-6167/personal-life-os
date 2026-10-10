from pathlib import Path

# ---- database.dart: schema v26 wellness tables ----
dbp = Path('apps/flutter/lib/data/database.dart')
db = dbp.read_text()
if 'schemaVersion = 26' not in db:
    db = db.replace('schemaVersion = 25', 'schemaVersion = 26', 1)
    db = db.replace(
        "await _migrateToV25(db);",
        "await _migrateToV25(db);\n        await _migrateToV26(db);",
    )
    if 'if (oldVersion < 26)' not in db:
        db = db.replace(
            "if (oldVersion < 25) await _migrateToV25(db);",
            "if (oldVersion < 25) await _migrateToV25(db);\n        if (oldVersion < 26) await _migrateToV26(db);",
            1,
        )
    db = db.replace(
        "'users', 'goals', 'projects', 'tasks', 'life_areas', 'activity_events',",
        "'users', 'goals', 'projects', 'tasks', 'life_areas', 'wellness_checkins', 'health_metrics', 'activity_events',",
        1,
    )
    mig = '''
  Future<void> _migrateToV26(Database db) async {
    await db.execute("""
CREATE TABLE IF NOT EXISTS wellness_checkins (
  id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  day INTEGER NOT NULL,
  mood INTEGER,
  energy INTEGER,
  stress INTEGER,
  sleep_hours REAL,
  notes TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  UNIQUE(owner_id, day),
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
)
    """);
    await db.execute("""
CREATE TABLE IF NOT EXISTS health_metrics (
  id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  metric_type TEXT NOT NULL,
  value REAL NOT NULL,
  unit TEXT,
  measured_at INTEGER NOT NULL,
  notes TEXT,
  created_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
)
    """);
    await db.execute('CREATE INDEX IF NOT EXISTS idx_wellness_owner_day ON wellness_checkins(owner_id, day DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_health_metrics_type ON health_metrics(owner_id, metric_type, measured_at DESC)');
  }
'''
    if '_migrateToV26' not in db:
        needle = "    await _executeIgnoringDuplicateColumn(db, 'ALTER TABLE tasks ADD COLUMN life_area_id TEXT');\n  }"
        if needle not in db:
            raise SystemExit('v25 end not found')
        db = db.replace(needle, needle + '\n' + mig, 1)
    dbp.write_text(db)
    print('schema v26 ok')
else:
    print('schema already 26')

# ---- wellness resilient load ----
wp = Path('apps/flutter/lib/ui/screens/wellness_screen.dart')
w = wp.read_text()
old_load = """  Future<void> _load() async {
    final today = await _repo.todayCheckin();
    final week = await _repo.weeklySummary();
    final recent = await _repo.recentCheckins();
    if (!mounted) return;
    setState(() {
      _today = today;
      _week = week;
      _recent = recent;
      if (today != null) {
        _mood = (today['mood'] as int?) ?? 3;
        _energy = (today['energy'] as int?) ?? 3;
        _stress = (today['stress'] as int?) ?? 3;
        _sleep = (today['sleep_hours'] as num?)?.toDouble() ?? 7;
      }
      _loading = false;
    });
  }"""
new_load = """  Future<void> _load() async {
    try {
      final today = await _repo.todayCheckin();
      final week = await _repo.weeklySummary();
      final recent = await _repo.recentCheckins();
      if (!mounted) return;
      setState(() {
        _today = today;
        _week = week;
        _recent = recent;
        if (today != null) {
          _mood = (today['mood'] as int?) ?? 3;
          _energy = (today['energy'] as int?) ?? 3;
          _stress = (today['stress'] as int?) ?? 3;
          _sleep = (today['sleep_hours'] as num?)?.toDouble() ?? 7;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Wellness data unavailable: $e')),
      );
    }
  }"""
if old_load in w:
    w = w.replace(old_load, new_load, 1)
    print('wellness load ok')
else:
    print('wellness load pattern miss')
wp.write_text(w)

# schedule
sp = Path('apps/flutter/lib/ui/screens/schedule_screen.dart')
s = sp.read_text()
old_s = """  Future<void> _load() async {
    if (mounted && _built == null) setState(() => _loading = true);
    final built = await _engine.build(day: _day);
    final open = await _tasks.listOpen();
    if (!mounted) return;
    setState(() {
      _built = built;
      _open = open;
      _loading = false;
    });
  }"""
new_s = """  Future<void> _load() async {
    if (mounted && _built == null) setState(() => _loading = true);
    try {
      final built = await _engine.build(day: _day);
      final open = await _tasks.listOpen();
      if (!mounted) return;
      setState(() {
        _built = built;
        _open = open;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Schedule failed to load: $e')),
      );
    }
  }"""
if old_s in s:
    s = s.replace(old_s, new_s, 1)
    print('schedule load ok')
else:
    print('schedule load miss')
sp.write_text(s)

# planning
pp = Path('apps/flutter/lib/ui/screens/planning_screen.dart')
p = pp.read_text()
old_p = """  Future<void> _load() async {
    if (mounted && _built == null) setState(() => _loading = true);
    final built = await _engine.build(day: _day);
    final free = await _plan.availableMinutes(day: _day);
    final open = await _tasks.listOpen();
    final scheduledIds = built.timeline
        .where((s) => s.kind == DaySlotKind.task && s.entityId != null)
        .map((s) => s.entityId!)
        .toSet();
    final unscheduled = open.where((t) => !scheduledIds.contains(t.id)).toList();
    final ranked = await _dayPlanner.rankForToday();
    if (!mounted) return;
    setState(() {
      _built = built;
      _freeMin = free;
      _unscheduled = unscheduled;
      _ranked = ranked;
      _loading = false;
    });
  }"""
new_p = """  Future<void> _load() async {
    if (mounted && _built == null) setState(() => _loading = true);
    try {
      final built = await _engine.build(day: _day);
      final free = await _plan.availableMinutes(day: _day);
      final open = await _tasks.listOpen();
      final scheduledIds = built.timeline
          .where((s) => s.kind == DaySlotKind.task && s.entityId != null)
          .map((s) => s.entityId!)
          .toSet();
      final unscheduled = open.where((t) => !scheduledIds.contains(t.id)).toList();
      final ranked = await _dayPlanner.rankForToday();
      if (!mounted) return;
      setState(() {
        _built = built;
        _freeMin = free;
        _unscheduled = unscheduled;
        _ranked = ranked;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Day plan failed to load: $e')),
      );
    }
  }"""
if old_p in p:
    p = p.replace(old_p, new_p, 1)
    print('planning load ok')
else:
    print('planning load miss')
pp.write_text(p)

# note detail
np = Path('apps/flutter/lib/ui/screens/note_detail_screen.dart')
n = np.read_text()
if "import '../../services/app_data_bus.dart';" not in n:
    n = n.replace(
        "import 'package:flutter/material.dart';",
        "import 'package:flutter/material.dart';\n\nimport '../../services/app_data_bus.dart';",
        1,
    )
n = n.replace('bool _editing = false;', 'bool _editing = true;', 1)
if 'Note data unavailable' not in n:
    n = n.replace(
        '  Future<void> _load() async {\n    final n = await NoteRepository',
        '  Future<void> _load() async {\n    try {\n    final n = await NoteRepository',
        1,
    )
    n = n.replace(
        """    if (n != null) {
      await _scanMentions(content: n.content, title: n.title);
    }
  }""",
        """    if (n != null) {
      await _scanMentions(content: n.content, title: n.title);
    }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Note data unavailable: $e')),
      );
    }
  }""",
        1,
    )
    print('note load try ok')
if 'AppDataBus.instance.lifeChanged()' not in n:
    n = n.replace(
        'setState(() => _editing = false);',
        'AppDataBus.instance.lifeChanged();\n      setState(() => _editing = false);',
        1,
    )
    print('note bus ok')
np.write_text(n)
print('DONE')
