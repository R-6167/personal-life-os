import React, { useState } from 'react';
import {
  Modal,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import { useAppData } from '../context/AppDataContext';
import { Card, Chip, EmptyState, PrimaryButton, SectionHeader } from '../components/ui';

export function RoutinesScreen() {
  const { routines, routineOccurrences, createRoutine, completeRoutine } = useAppData();
  const [open, setOpen] = useState(false);
  const [title, setTitle] = useState('');
  const [stepsText, setStepsText] = useState('');
  const [saving, setSaving] = useState(false);

  const due = routineOccurrences.filter((r) => r.status === 'EXPECTED');

  const submit = async () => {
    if (!title.trim() || saving) return;
    setSaving(true);
    try {
      const steps = stepsText
        .split('\n')
        .map((s) => s.trim())
        .filter(Boolean);
      await createRoutine({ title: title.trim(), steps });
      setTitle('');
      setStepsText('');
      setOpen(false);
    } finally {
      setSaving(false);
    }
  };

  return (
    <>
      <ScrollView style={styles.scroll} contentContainerStyle={styles.content}>
        <View style={styles.topRow}>
          <SectionHeader title="Today's routines" count={due.length} />
          <PrimaryButton label="+ Routine" onPress={() => setOpen(true)} />
        </View>
        {due.length === 0 ? (
          <EmptyState message="No routines due today" />
        ) : (
          due.map((r) => (
            <Card key={r.id} style={styles.card}>
              <View style={styles.row}>
                <Text style={styles.title}>{r.title}</Text>
                <PrimaryButton label="Done" onPress={() => completeRoutine(r.id)} />
              </View>
            </Card>
          ))
        )}

        <SectionHeader title="All routines" count={routines.length} />
        {routines.length === 0 ? (
          <EmptyState message="No routines yet" />
        ) : (
          routines.map((r) => (
            <Card key={r.id} style={styles.card}>
              <Text style={styles.title}>{r.title}</Text>
              {r.description ? <Text style={styles.desc}>{r.description}</Text> : null}
              <View style={styles.meta}>
                <Chip label={r.frequency} />
                {r.estimatedMinutes ? <Chip label={`${r.estimatedMinutes} min`} /> : null}
                <Chip label={`${r.steps.length} steps`} />
              </View>
              {r.steps.length > 0 ? (
                <View style={styles.steps}>
                  {r.steps.map((s, i) => (
                    <Text key={s.id} style={styles.step}>
                      {i + 1}. {s.title}
                    </Text>
                  ))}
                </View>
              ) : null}
            </Card>
          ))
        )}
      </ScrollView>

      <Modal visible={open} animationType="slide" transparent onRequestClose={() => setOpen(false)}>
        <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={styles.backdrop}>
          <View style={styles.sheet}>
            <Text style={styles.heading}>New routine</Text>
            <TextInput
              style={styles.input}
              placeholder="Routine name (e.g. Morning)"
              placeholderTextColor="#64748b"
              value={title}
              onChangeText={setTitle}
              autoFocus
            />
            <TextInput
              style={[styles.input, styles.stepsInput]}
              placeholder="Steps (one per line)"
              placeholderTextColor="#64748b"
              value={stepsText}
              onChangeText={setStepsText}
              multiline
            />
            <View style={styles.actions}>
              <TouchableOpacity onPress={() => setOpen(false)}>
                <Text style={styles.cancel}>Cancel</Text>
              </TouchableOpacity>
              <PrimaryButton label={saving ? 'Saving…' : 'Create'} onPress={submit} disabled={!title.trim() || saving} />
            </View>
          </View>
        </KeyboardAvoidingView>
      </Modal>
    </>
  );
}

const styles = StyleSheet.create({
  scroll: { flex: 1 },
  content: { padding: 16, paddingBottom: 40 },
  topRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 },
  card: { marginBottom: 10 },
  row: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 10 },
  title: { color: '#f8fafc', fontSize: 15, fontWeight: '700', flex: 1 },
  desc: { color: '#94a3b8', fontSize: 13, marginTop: 4 },
  meta: { flexDirection: 'row', flexWrap: 'wrap', gap: 6, marginTop: 8 },
  steps: { marginTop: 10, borderTopWidth: 1, borderTopColor: '#1f2937', paddingTop: 8 },
  step: { color: '#cbd5e1', fontSize: 13, marginBottom: 4 },
  backdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.55)', justifyContent: 'flex-end' },
  sheet: {
    backgroundColor: '#111827',
    borderTopLeftRadius: 16,
    borderTopRightRadius: 16,
    padding: 20,
    borderWidth: 1,
    borderColor: '#1f2937',
  },
  heading: { color: '#f8fafc', fontSize: 18, fontWeight: '700', marginBottom: 14 },
  input: {
    backgroundColor: '#0f172a',
    borderWidth: 1,
    borderColor: '#1f2937',
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 10,
    color: '#f1f5f9',
    fontSize: 15,
    marginBottom: 10,
  },
  stepsInput: { minHeight: 100, textAlignVertical: 'top' },
  actions: { flexDirection: 'row', justifyContent: 'flex-end', alignItems: 'center', gap: 16 },
  cancel: { color: '#94a3b8', fontWeight: '600' },
});
