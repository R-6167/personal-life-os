import React, { useState } from 'react';
import {
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
  TouchableOpacity,
} from 'react-native';
import { useAppData } from '../context/AppDataContext';
import { Card, Chip, EmptyState, PrimaryButton, SectionHeader } from '../components/ui';
import { formatTime } from '../components/ui';

export function CaptureScreen() {
  const {
    inbox,
    captureInbox,
    processInboxToTask,
    processInboxToNote,
    dismissInbox,
  } = useAppData();
  const [text, setText] = useState('');
  const [saving, setSaving] = useState(false);

  const submit = async () => {
    if (!text.trim() || saving) return;
    setSaving(true);
    try {
      await captureInbox(text.trim());
      setText('');
    } finally {
      setSaving(false);
    }
  };

  return (
    <ScrollView style={styles.scroll} contentContainerStyle={styles.content}>
      <SectionHeader title="Quick capture" />
      <Card>
        <Text style={styles.hint}>
          Dump anything here. Classify later into task, note, or dismiss.
        </Text>
        <TextInput
          style={styles.input}
          placeholder="What's on your mind?"
          placeholderTextColor="#64748b"
          value={text}
          onChangeText={setText}
          multiline
        />
        <PrimaryButton label={saving ? 'Saving…' : 'Capture'} onPress={submit} disabled={!text.trim() || saving} />
      </Card>

      <SectionHeader title="Inbox" count={inbox.length} />
      {inbox.length === 0 ? (
        <EmptyState message="Inbox is clear" />
      ) : (
        inbox.map((item) => (
          <Card key={item.id} style={styles.item}>
            <Text style={styles.itemText}>{item.rawText}</Text>
            <View style={styles.meta}>
              {item.suggestedType ? <Chip label={item.suggestedType} /> : null}
              <Text style={styles.time}>{formatTime(item.createdAt)}</Text>
            </View>
            <View style={styles.actions}>
              <TouchableOpacity style={styles.btn} onPress={() => processInboxToTask(item.id)}>
                <Text style={styles.btnText}>→ Task</Text>
              </TouchableOpacity>
              <TouchableOpacity style={styles.btn} onPress={() => processInboxToNote(item.id)}>
                <Text style={styles.btnText}>→ Note</Text>
              </TouchableOpacity>
              <TouchableOpacity style={[styles.btn, styles.ghost]} onPress={() => dismissInbox(item.id)}>
                <Text style={styles.ghostText}>Dismiss</Text>
              </TouchableOpacity>
            </View>
          </Card>
        ))
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  scroll: { flex: 1 },
  content: { padding: 16, paddingBottom: 40 },
  hint: { color: '#94a3b8', fontSize: 12, marginBottom: 10, lineHeight: 18 },
  input: {
    backgroundColor: '#0f172a',
    borderWidth: 1,
    borderColor: '#1f2937',
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 10,
    color: '#f1f5f9',
    fontSize: 15,
    minHeight: 80,
    textAlignVertical: 'top',
    marginBottom: 12,
  },
  item: { marginBottom: 10 },
  itemText: { color: '#f1f5f9', fontSize: 15, lineHeight: 21 },
  meta: { flexDirection: 'row', alignItems: 'center', gap: 8, marginTop: 8 },
  time: { color: '#64748b', fontSize: 11 },
  actions: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginTop: 12 },
  btn: {
    backgroundColor: '#1d4ed8',
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 8,
  },
  btnText: { color: '#eff6ff', fontWeight: '700', fontSize: 12 },
  ghost: { backgroundColor: 'transparent', borderWidth: 1, borderColor: '#334155' },
  ghostText: { color: '#94a3b8', fontWeight: '600', fontSize: 12 },
});
