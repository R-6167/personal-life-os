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

export function CreateHabitModal({
  visible,
  onClose,
}: {
  visible: boolean;
  onClose: () => void;
}) {
  const { createHabit } = useAppData();
  const [title, setTitle] = useState('');
  const [minutes, setMinutes] = useState('');
  const [saving, setSaving] = useState(false);

  const submit = async () => {
    if (!title.trim() || saving) return;
    setSaving(true);
    try {
      const m = parseInt(minutes, 10);
      await createHabit({
        title: title.trim(),
        targetMinutes: Number.isFinite(m) && m > 0 ? m : undefined,
      });
      setTitle('');
      setMinutes('');
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
          <Text style={styles.heading}>New habit</Text>
          <TextInput
            style={styles.input}
            placeholder="Habit name"
            placeholderTextColor="#64748b"
            value={title}
            onChangeText={setTitle}
            autoFocus
          />
          <TextInput
            style={styles.input}
            placeholder="Target minutes (optional)"
            placeholderTextColor="#64748b"
            value={minutes}
            onChangeText={setMinutes}
            keyboardType="number-pad"
          />
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
