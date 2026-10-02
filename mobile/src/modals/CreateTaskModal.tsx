import React, { useState } from 'react';
import {
  Modal,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import { useAppData } from '../context/AppDataContext';

export function CreateTaskModal({
  visible,
  onClose,
}: {
  visible: boolean;
  onClose: () => void;
}) {
  const { createTask, projects } = useAppData();
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [projectId, setProjectId] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const submit = async () => {
    if (!title.trim() || saving) return;
    setSaving(true);
    try {
      await createTask({
        title: title.trim(),
        description: description.trim() || undefined,
        projectId,
      });
      setTitle('');
      setDescription('');
      setProjectId(null);
      onClose();
    } finally {
      setSaving(false);
    }
  };

  return (
    <Modal visible={visible} animationType="slide" transparent onRequestClose={onClose}>
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        style={styles.backdrop}
      >
        <View style={styles.sheet}>
          <Text style={styles.heading}>New task</Text>
          <TextInput
            style={styles.input}
            placeholder="What needs doing?"
            placeholderTextColor="#64748b"
            value={title}
            onChangeText={setTitle}
            autoFocus
          />
          <TextInput
            style={[styles.input, styles.multiline]}
            placeholder="Notes (optional)"
            placeholderTextColor="#64748b"
            value={description}
            onChangeText={setDescription}
            multiline
          />
          {projects.length > 0 ? (
            <View style={styles.projectRow}>
              <Text style={styles.label}>Project</Text>
              <View style={styles.chips}>
                <TouchableOpacity
                  style={[styles.chip, !projectId && styles.chipActive]}
                  onPress={() => setProjectId(null)}
                >
                  <Text style={styles.chipText}>None</Text>
                </TouchableOpacity>
                {projects.slice(0, 6).map((p) => (
                  <TouchableOpacity
                    key={p.id}
                    style={[styles.chip, projectId === p.id && styles.chipActive]}
                    onPress={() => setProjectId(p.id)}
                  >
                    <Text style={styles.chipText}>{p.title}</Text>
                  </TouchableOpacity>
                ))}
              </View>
            </View>
          ) : null}
          <View style={styles.actions}>
            <TouchableOpacity style={styles.cancel} onPress={onClose}>
              <Text style={styles.cancelText}>Cancel</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.save, !title.trim() && styles.saveDisabled]}
              onPress={submit}
              disabled={!title.trim() || saving}
            >
              <Text style={styles.saveText}>{saving ? 'Saving…' : 'Create'}</Text>
            </TouchableOpacity>
          </View>
        </View>
      </KeyboardAvoidingView>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.55)',
    justifyContent: 'flex-end',
  },
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
  multiline: { minHeight: 72, textAlignVertical: 'top' },
  label: { color: '#94a3b8', fontSize: 12, fontWeight: '600', marginBottom: 6 },
  projectRow: { marginBottom: 8 },
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
  actions: { flexDirection: 'row', justifyContent: 'flex-end', gap: 10, marginTop: 12 },
  cancel: { paddingHorizontal: 14, paddingVertical: 10 },
  cancelText: { color: '#94a3b8', fontWeight: '600' },
  save: {
    backgroundColor: '#2563eb',
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 8,
  },
  saveDisabled: { opacity: 0.5 },
  saveText: { color: '#eff6ff', fontWeight: '700' },
});
