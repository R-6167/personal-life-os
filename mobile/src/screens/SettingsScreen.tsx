import React, { useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import * as DocumentPicker from 'expo-document-picker';
import { getDatabase } from '../db/database';
import { exportBackup, importBackupFromUri } from '../backup/backup';
import { Card, PrimaryButton, SectionHeader } from '../components/ui';
import { useAppData } from '../context/AppDataContext';
import { ensureHabitOccurrences } from '../habits/recurrence';

export function SettingsScreen() {
  const { refresh } = useAppData();
  const [passphrase, setPassphrase] = useState('');
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState<string | null>(null);

  const run = async (fn: () => Promise<void>) => {
    setBusy(true);
    setStatus(null);
    try {
      await fn();
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      setStatus(msg);
      Alert.alert('Error', msg);
    } finally {
      setBusy(false);
    }
  };

  const onExportEncrypted = () =>
    run(async () => {
      if (passphrase.length < 4) {
        throw new Error('Enter a passphrase of at least 4 characters for encrypted export');
      }
      const db = await getDatabase();
      const path = await exportBackup(db, passphrase);
      setStatus(`Encrypted backup shared.\n${path}`);
    });

  const onExportPlain = () =>
    run(async () => {
      const db = await getDatabase();
      const path = await exportBackup(db);
      setStatus(`Plain backup shared.\n${path}`);
    });

  const onImport = () =>
    run(async () => {
      const result = await DocumentPicker.getDocumentAsync({
        type: ['application/json', 'text/plain', '*/*'],
        copyToCacheDirectory: true,
      });
      if (result.canceled || !result.assets?.[0]) {
        setStatus('Import cancelled');
        return;
      }
      const uri = result.assets[0].uri;
      const db = await getDatabase();
      const stats = await importBackupFromUri(
        db,
        uri,
        passphrase.length >= 4 ? passphrase : undefined
      );
      await ensureHabitOccurrences(db, { daysAhead: 0 });
      await refresh();
      setStatus(`Restored ${stats.rows} rows across ${stats.tables} tables.`);
      Alert.alert('Restore complete', `Restored ${stats.rows} rows.`);
    });

  const onGenerateHabits = () =>
    run(async () => {
      const db = await getDatabase();
      const r = await ensureHabitOccurrences(db, { daysAhead: 1 });
      await refresh();
      setStatus(`Habits: generated ${r.generated}, marked missed ${r.missed}.`);
    });

  return (
    <ScrollView style={styles.scroll} contentContainerStyle={styles.content}>
      <SectionHeader title="Backup & restore" />
      <Card>
        <Text style={styles.body}>
          Export a full local backup of your life data. Use a passphrase to encrypt the file
          before sharing or saving offline.
        </Text>
        <Text style={styles.label}>Passphrase (for encrypted export / import)</Text>
        <TextInput
          style={styles.input}
          placeholder="Optional for plain export"
          placeholderTextColor="#64748b"
          secureTextEntry
          value={passphrase}
          onChangeText={setPassphrase}
          autoCapitalize="none"
        />
        <View style={styles.row}>
          <PrimaryButton label="Export encrypted" onPress={onExportEncrypted} disabled={busy} />
          <PrimaryButton label="Export plain" tone="ghost" onPress={onExportPlain} disabled={busy} />
        </View>
        <View style={[styles.row, { marginTop: 10 }]}>
          <PrimaryButton label="Import backup…" onPress={onImport} disabled={busy} />
        </View>
        {busy ? (
          <View style={styles.busy}>
            <ActivityIndicator color="#60a5fa" />
          </View>
        ) : null}
        {status ? <Text style={styles.status}>{status}</Text> : null}
      </Card>

      <SectionHeader title="Habits" />
      <Card>
        <Text style={styles.body}>
          Occurrences for today are generated automatically when the app opens. You can also
          run generation manually (marks missed days and creates today / tomorrow).
        </Text>
        <PrimaryButton label="Generate occurrences now" onPress={onGenerateHabits} disabled={busy} />
      </Card>

      <SectionHeader title="Privacy" />
      <Card>
        <Text style={styles.body}>
          Data stays on this device in SQLite. Encrypted backups use a passphrase-derived
          stream cipher with an integrity check. Keep your passphrase safe — it cannot be
          recovered.
        </Text>
      </Card>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  scroll: { flex: 1 },
  content: { padding: 16, paddingBottom: 40 },
  body: { color: '#cbd5e1', fontSize: 13, lineHeight: 19, marginBottom: 12 },
  label: { color: '#94a3b8', fontSize: 12, fontWeight: '600', marginBottom: 6 },
  input: {
    backgroundColor: '#0f172a',
    borderWidth: 1,
    borderColor: '#1f2937',
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 10,
    color: '#f1f5f9',
    fontSize: 15,
    marginBottom: 12,
  },
  row: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  busy: { marginTop: 12, alignItems: 'flex-start' },
  status: { color: '#86efac', fontSize: 12, marginTop: 12, lineHeight: 18 },
});
