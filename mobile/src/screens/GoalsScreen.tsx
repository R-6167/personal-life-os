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
import { Card, Chip, EmptyState, PrimaryButton, SectionHeader, formatDate } from '../components/ui';

export function GoalsScreen() {
  const { goals, createGoal } = useAppData();
  const [open, setOpen] = useState(false);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [saving, setSaving] = useState(false);

  const submit = async () => {
    if (!title.trim() || saving) return;
    setSaving(true);
    try {
      await createGoal({ title: title.trim(), description: description.trim() || undefined });
      setTitle('');
      setDescription('');
      setOpen(false);
    } finally {
      setSaving(false);
    }
  };

  return (
    <View style={{ flex: 1 }}>
      <ScrollView style={styles.scroll} contentContainerStyle={styles.content}>
        <SectionHeader title="Goals" count={goals.length} />
        {goals.length === 0 ? (
          <EmptyState message="No goals yet. Add one to connect projects and habits." />
        ) : (
          goals.map((g) => (
            <Card key={g.id}>
              <View style={styles.rowBetween}>
                <Text style={styles.title}>{g.title}</Text>
                <Chip label={g.status} tone={g.status === 'ACTIVE' ? 'info' : 'neutral'} />
              </View>
              {g.description ? <Text style={styles.desc}>{g.description}</Text> : null}
              <Text style={styles.meta}>
                {[
                  g.targetDate ? `Target ${formatDate(g.targetDate)}` : null,
                  `${g.projectCount} projects`,
                  `${g.openTasks} open tasks`,
                  `P${g.priority}`,
                ]
                  .filter(Boolean)
                  .join(' · ')}
              </Text>
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
            <Text style={styles.heading}>New goal</Text>
            <TextInput
              style={styles.input}
              placeholder="Goal title"
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
  actions: { flexDirection: 'row', gap: 8, justifyContent: 'flex-end', marginTop: 8 },
});
