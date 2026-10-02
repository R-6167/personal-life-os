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
import { Card, EmptyState, PrimaryButton, SectionHeader } from '../components/ui';
import { formatDate } from '../components/ui';

export function NotesScreen() {
  const { notes, createNote, toggleNotePin } = useAppData();
  const [open, setOpen] = useState(false);
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [saving, setSaving] = useState(false);

  const submit = async () => {
    if (!body.trim() || saving) return;
    setSaving(true);
    try {
      await createNote({ title: title.trim() || undefined, body: body.trim() });
      setTitle('');
      setBody('');
      setOpen(false);
    } finally {
      setSaving(false);
    }
  };

  return (
    <>
      <ScrollView style={styles.scroll} contentContainerStyle={styles.content}>
        <View style={styles.topRow}>
          <SectionHeader title="Notes" count={notes.length} />
          <PrimaryButton label="+ Note" onPress={() => setOpen(true)} />
        </View>
        {notes.length === 0 ? (
          <EmptyState message="No notes yet" />
        ) : (
          notes.map((n) => (
            <Card key={n.id} style={styles.card}>
              <View style={styles.row}>
                <Text style={styles.title}>{n.title || 'Untitled'}</Text>
                <TouchableOpacity onPress={() => toggleNotePin(n.id)}>
                  <Text style={styles.pin}>{n.pinned ? '📌' : '📍'}</Text>
                </TouchableOpacity>
              </View>
              <Text style={styles.body} numberOfLines={4}>
                {n.body}
              </Text>
              <Text style={styles.meta}>{formatDate(n.updatedAt)}</Text>
            </Card>
          ))
        )}
      </ScrollView>

      <Modal visible={open} animationType="slide" transparent onRequestClose={() => setOpen(false)}>
        <KeyboardAvoidingView
          behavior={Platform.OS === 'ios' ? 'padding' : undefined}
          style={styles.backdrop}
        >
          <View style={styles.sheet}>
            <Text style={styles.heading}>New note</Text>
            <TextInput
              style={styles.input}
              placeholder="Title (optional)"
              placeholderTextColor="#64748b"
              value={title}
              onChangeText={setTitle}
            />
            <TextInput
              style={[styles.input, styles.bodyInput]}
              placeholder="Write something…"
              placeholderTextColor="#64748b"
              value={body}
              onChangeText={setBody}
              multiline
              autoFocus
            />
            <View style={styles.actions}>
              <TouchableOpacity onPress={() => setOpen(false)}>
                <Text style={styles.cancel}>Cancel</Text>
              </TouchableOpacity>
              <PrimaryButton label={saving ? 'Saving…' : 'Save'} onPress={submit} disabled={!body.trim() || saving} />
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
  row: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  title: { color: '#f8fafc', fontSize: 16, fontWeight: '700', flex: 1 },
  pin: { fontSize: 16, paddingLeft: 8 },
  body: { color: '#cbd5e1', fontSize: 13, lineHeight: 19, marginTop: 6 },
  meta: { color: '#64748b', fontSize: 11, marginTop: 8 },
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
  bodyInput: { minHeight: 120, textAlignVertical: 'top' },
  actions: { flexDirection: 'row', justifyContent: 'flex-end', alignItems: 'center', gap: 16, marginTop: 8 },
  cancel: { color: '#94a3b8', fontWeight: '600' },
});
