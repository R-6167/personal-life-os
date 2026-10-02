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

export function ProjectsScreen() {
  const { projects, goals, createProject } = useAppData();
  const [open, setOpen] = useState(false);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [goalId, setGoalId] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const submit = async () => {
    if (!title.trim() || saving) return;
    setSaving(true);
    try {
      await createProject({
        title: title.trim(),
        description: description.trim() || undefined,
        goalId,
      });
      setTitle('');
      setDescription('');
      setGoalId(null);
      setOpen(false);
    } finally {
      setSaving(false);
    }
  };

  return (
    <View style={{ flex: 1 }}>
      <ScrollView style={styles.scroll} contentContainerStyle={styles.content}>
        <SectionHeader title="Projects" count={projects.length} />
        {projects.length === 0 ? (
          <EmptyState message="No projects yet." />
        ) : (
          projects.map((p) => (
            <Card key={p.id}>
              <View style={styles.rowBetween}>
                <Text style={styles.title}>{p.title}</Text>
                <Chip label={p.status} tone={p.status === 'ACTIVE' ? 'info' : 'neutral'} />
              </View>
              {p.description ? <Text style={styles.desc}>{p.description}</Text> : null}
              <Text style={styles.meta}>
                {[
                  p.goalTitle ? `Goal: ${p.goalTitle}` : null,
                  `${p.openTasks} open`,
                  `${p.completedTasks} done`,
                  `${p.progress}%`,
                ]
                  .filter(Boolean)
                  .join(' · ')}
              </Text>
              <View style={styles.progressTrack}>
                <View style={[styles.progressFill, { width: `${Math.min(100, p.progress)}%` as any }]} />
              </View>
            </Card>
          ))
        )}
      </ScrollView>
      <TouchableOpacity style={styles.fab} onPress={() => setOpen(true)} activeOpacity={0.9}>
        <Text style={styles.fabText}>+</Text>
      </TouchableOpacity>

      <Modal visible={open} animationType="slide" transparent onRequestClose={() => setOpen(false)}>
        <KeyboardAvoidingView
          behavior={Platform.OS === 'ios' ? 'padding' : undefined}
          style={styles.backdrop}
        >
          <View style={styles.sheet}>
            <Text style={styles.heading}>New project</Text>
            <TextInput
              style={styles.input}
              placeholder="Project title"
              placeholderTextColor="#64748b"
              value={title}
              onChangeText={setTitle}
              autoFocus
            />
            <TextInput
              style={[styles.input, { minHeight: 72, textAlignVertical: 'top' }]}
              placeholder="Description (optional)"
              placeholderTextColor="#64748b"
              value={description}
              onChangeText={setDescription}
              multiline
            />
            {goals.length > 0 ? (
              <View style={{ marginBottom: 8 }}>
                <Text style={styles.label}>Linked goal</Text>
                <View style={styles.chips}>
                  <TouchableOpacity
                    style={[styles.chip, !goalId && styles.chipActive]}
                    onPress={() => setGoalId(null)}
                  >
                    <Text style={styles.chipText}>None</Text>
                  </TouchableOpacity>
                  {goals.map((g) => (
                    <TouchableOpacity
                      key={g.id}
                      style={[styles.chip, goalId === g.id && styles.chipActive]}
                      onPress={() => setGoalId(g.id)}
                    >
                      <Text style={styles.chipText}>{g.title}</Text>
                    </TouchableOpacity>
                  ))}
                </View>
              </View>
            ) : null}
            <View style={styles.actions}>
              <PrimaryButton label="Cancel" tone="ghost" onPress={() => setOpen(false)} />
              <PrimaryButton
                label={saving ? 'Saving…' : 'Create'}
                onPress={submit}
                disabled={!title.trim() || saving}
              />
            </View>
          </View>
        </KeyboardAvoidingView>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  scroll: { flex: 1 },
  content: { padding: 16, paddingBottom: 88 },
  rowBetween: { flexDirection: 'row', justifyContent: 'space-between', gap: 8 },
  title: { color: '#f8fafc', fontSize: 15, fontWeight: '700', flex: 1 },
  desc: { color: '#cbd5e1', fontSize: 13, marginTop: 6 },
  meta: { color: '#94a3b8', fontSize: 12, marginTop: 8 },
  progressTrack: {
    height: 6,
    backgroundColor: '#1f2937',
    borderRadius: 999,
    marginTop: 10,
    overflow: 'hidden',
  },
  progressFill: { height: '100%', backgroundColor: '#3b82f6', borderRadius: 999 },
  fab: {
    position: 'absolute',
    right: 20,
    bottom: 20,
    width: 52,
    height: 52,
    borderRadius: 26,
    backgroundColor: '#2563eb',
    alignItems: 'center',
    justifyContent: 'center',
    elevation: 4,
  },
  fabText: { color: '#eff6ff', fontSize: 28, fontWeight: '600', marginTop: -2 },
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
  label: { color: '#94a3b8', fontSize: 12, fontWeight: '600', marginBottom: 6 },
  chips: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  chip: {
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 999,
    backgroundColor: '#0f172a',
    borderWidth: 1,
    borderColor: '#1f2937',
  },
  chipActive: { backgroundColor: '#1d4ed8', borderColor: '#60a5fa' },
  chipText: { color: '#e2e8f0', fontSize: 12, fontWeight: '600' },
  actions: { flexDirection: 'row', gap: 8, justifyContent: 'flex-end', marginTop: 8 },
});
