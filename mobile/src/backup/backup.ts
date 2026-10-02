import * as FileSystem from 'expo-file-system';
import * as Sharing from 'expo-sharing';
import type { Db } from '../db/database';
import { DEFAULT_OWNER_ID } from '../db/database';
import { decryptString, encryptString, type EncryptedPayload } from './crypto';

const TABLES = [
  'users',
  'goals',
  'projects',
  'tasks',
  'habits',
  'habit_occurrences',
  'financial_accounts',
  'bills',
  'bill_occurrences',
  'expenses',
  'activity_events',
  'app_meta',
] as const;

export type BackupDocument = {
  format: 'personal-life-os-backup';
  version: 1;
  exportedAt: number;
  ownerId: string;
  tables: Record<string, Record<string, unknown>[]>;
};

export type BackupFile =
  | { encrypted: false; document: BackupDocument }
  | { encrypted: true; payload: EncryptedPayload };

async function dumpTables(db: Db): Promise<BackupDocument> {
  const tables: Record<string, Record<string, unknown>[]> = {};
  for (const name of TABLES) {
    try {
      const rows = await db.getAllAsync<Record<string, unknown>>(`SELECT * FROM ${name}`);
      tables[name] = rows;
    } catch {
      tables[name] = [];
    }
  }
  return {
    format: 'personal-life-os-backup',
    version: 1,
    exportedAt: Date.now(),
    ownerId: DEFAULT_OWNER_ID,
    tables,
  };
}

export async function createBackupJson(db: Db, passphrase?: string): Promise<string> {
  const document = await dumpTables(db);
  if (passphrase && passphrase.length > 0) {
    const payload = await encryptString(JSON.stringify(document), passphrase);
    const file: BackupFile = { encrypted: true, payload };
    return JSON.stringify(file, null, 2);
  }
  const file: BackupFile = { encrypted: false, document };
  return JSON.stringify(file, null, 2);
}

export async function exportBackup(db: Db, passphrase?: string): Promise<string> {
  const json = await createBackupJson(db, passphrase);
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const suffix = passphrase ? 'encrypted' : 'plain';
  const path = `${FileSystem.documentDirectory}plos-backup-${stamp}-${suffix}.json`;
  await FileSystem.writeAsStringAsync(path, json, {
    encoding: FileSystem.EncodingType.UTF8,
  });
  if (await Sharing.isAvailableAsync()) {
    await Sharing.shareAsync(path, {
      mimeType: 'application/json',
      dialogTitle: 'Export Personal Life OS backup',
      UTI: 'public.json',
    });
  }
  return path;
}

function parseBackupFile(raw: string): BackupFile {
  const parsed = JSON.parse(raw);
  if (parsed.encrypted === true && parsed.payload) return parsed as BackupFile;
  if (parsed.encrypted === false && parsed.document) return parsed as BackupFile;
  if (parsed.format === 'personal-life-os-backup') {
    return { encrypted: false, document: parsed as BackupDocument };
  }
  throw new Error('Unrecognized backup file');
}

export async function readBackupDocument(
  raw: string,
  passphrase?: string
): Promise<BackupDocument> {
  const file = parseBackupFile(raw);
  if (!file.encrypted) return file.document;
  if (!passphrase) throw new Error('This backup is encrypted — enter the passphrase');
  const plain = await decryptString(file.payload, passphrase);
  const doc = JSON.parse(plain) as BackupDocument;
  if (doc.format !== 'personal-life-os-backup') throw new Error('Invalid decrypted backup');
  return doc;
}

export async function restoreBackup(
  db: Db,
  document: BackupDocument
): Promise<{ tables: number; rows: number }> {
  if (document.format !== 'personal-life-os-backup') {
    throw new Error('Invalid backup document');
  }

  let tables = 0;
  let rows = 0;

  await db.execAsync('PRAGMA foreign_keys = OFF;');
  await db.withTransactionAsync(async () => {
    const clearOrder = [...TABLES].reverse();
    for (const name of clearOrder) {
      if (name === 'users') {
        await db.runAsync(`DELETE FROM users WHERE id = ?`, DEFAULT_OWNER_ID);
      } else {
        try {
          await db.runAsync(`DELETE FROM ${name} WHERE owner_id = ?`, DEFAULT_OWNER_ID);
        } catch {
          await db.runAsync(`DELETE FROM ${name}`);
        }
      }
    }

    for (const name of TABLES) {
      const list = document.tables[name] ?? [];
      if (list.length === 0) continue;
      tables += 1;
      for (const row of list) {
        const keys = Object.keys(row);
        const placeholders = keys.map(() => '?').join(', ');
        const sql = `INSERT OR REPLACE INTO ${name} (${keys.join(', ')}) VALUES (${placeholders})`;
        await db.runAsync(sql, ...keys.map((k) => row[k] as string | number | null));
        rows += 1;
      }
    }
  });
  await db.execAsync('PRAGMA foreign_keys = ON;');

  return { tables, rows };
}

export async function importBackupFromString(
  db: Db,
  raw: string,
  passphrase?: string
): Promise<{ tables: number; rows: number }> {
  const doc = await readBackupDocument(raw, passphrase);
  return restoreBackup(db, doc);
}

export async function importBackupFromUri(
  db: Db,
  uri: string,
  passphrase?: string
): Promise<{ tables: number; rows: number }> {
  const raw = await FileSystem.readAsStringAsync(uri, {
    encoding: FileSystem.EncodingType.UTF8,
  });
  return importBackupFromString(db, raw, passphrase);
}
