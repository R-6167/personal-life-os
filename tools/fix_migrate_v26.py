from pathlib import Path

p = Path('apps/flutter/lib/data/database.dart')
s = p.read_text()

# Remove accidental unconditional duplicate call in onUpgrade
s = s.replace(
    "        if (oldVersion < 26) await _migrateToV26(db);\n        await _migrateToV26(db);\n        await _verifySchemaContract(db);",
    "        if (oldVersion < 26) await _migrateToV26(db);\n        await _verifySchemaContract(db);",
    1,
)

method = '''
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

if 'Future<void> _migrateToV26' not in s:
    marker = '  Future<void> _migrateToV24(Database db) async {'
    if marker in s:
        s = s.replace(marker, method + '\n' + marker, 1)
    else:
        needle = "    await _executeIgnoringDuplicateColumn(db, 'ALTER TABLE tasks ADD COLUMN life_area_id TEXT');\n  }\n"
        if needle not in s:
            raise SystemExit('cannot find insert point')
        s = s.replace(needle, needle + method, 1)
    print('method inserted')
else:
    print('method already present')

if 'Future<void> _migrateToV26' not in s:
    raise SystemExit('still missing method')

p.write_text(s)
print('ok calls', s.count('await _migrateToV26(db);'))
