import React, { useMemo, useState } from 'react';
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
import { formatDate, formatTime } from '../components/ui';

export function CalendarScreen() {
  const { events, reminders, createEvent, createReminder, completeReminder } = useAppData();
  const [eventOpen, setEventOpen] = useState(false);
  const [remOpen, setRemOpen] = useState(false);
  const [title, setTitle] = useState('');
  const [location, setLocation] = useState('');
  const [hoursAhead, setHoursAhead] = useState('2');
  const [saving, setSaving] = useState(false);

  const upcomingEvents = useMemo(
    () => events.filter((e) => e.startsAt >= Date.now() - 3600000).slice(0, 20),
    [events]
  );

  const submitEvent = async () => {
    if (!title.trim() || saving) return;
    setSaving(true);
    try {
      const h = parseFloat(hoursAhead) || 2;
      const startsAt = Date.now() + h * 3600000;
      await createEvent({
        title: title.trim(),
        location: location.trim() || undefined,
        startsAt,
        endsAt: startsAt + 3600000,
      });
      setTitle('');
      setLocation('');
      setEventOpen(false);
    } finally {
      setSaving(false);
    }
  };

  const submitReminder = async () => {
    if (!title.trim() || saving) return;
    setSaving(true);
    try {
      const h = parseFloat(hoursAhead) || 1;
      await createReminder({
        title: title.trim(),
        remindAt: Date.now() + h * 3600000,
      });
      setTitle('');
      setRemOpen(false);
    } finally {
      setSaving(false);
    }
  };

  return (
    <>
      <ScrollView style={styles.scroll} contentContainerStyle={styles.content}>
        <View style={styles.topRow}>
          <SectionHeader title="Upcoming events" count={upcomingEvents.length} />
          <PrimaryButton label="+ Event" onPress={() => setEventOpen(true)} />
        </View>
        {upcomingEvents.length === 0 ? (
          <EmptyState message="No upcoming events" />
        ) : (
          upcomingEvents.map((e) => (
            <Card key={e.id} style={styles.card}>
              <Text style={styles.title}>{e.title}</Text>
              <View style={styles.meta}>
                <Chip label={formatDate(e.startsAt)} />
                <Text style={styles.sub}>{formatTime(e.startsAt)}</Text>
                {e.location ? <Text style={styles.sub}>· {e.location}</Text> : null}
              </View>
              {e.description ? <Text style={styles.desc}>{e.description}</Text> : null}
            </Card>
          ))
        )}

        <View style={[styles.topRow, { marginTop: 12 }]}>
          <SectionHeader title="Reminders" count={reminders.length} />
          <PrimaryButton label="+ Reminder" onPress={() => setRemOpen(true)} />
        </View>
        {reminders.length === 0 ? (
          <EmptyState message="No pending reminders" />
        ) : (
          reminders.map((r) => (
            <Card key={r.id} style={styles.card}>
              <View style={styles.row}>
                <View style={{ flex: 1 }}>
                  <Text style={styles.title}>{r.title}</Text>
                  <Text style={styles.sub}>
                    {formatDate(r.remindAt)} · {formatTime(r.remindAt)}
                  </Text>
                  {r.body ? <Text style={styles.desc}>{r.body}</Text> : null}
                </View>
                <PrimaryButton label="Done" onPress={() => completeReminder(r.id)} />
              </View>
            </Card>
          ))
        )}
      </ScrollView>

      <Modal visible={eventOpen} animationType="slide" transparent onRequestClose={() => setEventOpen(false)}>
        <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={styles.backdrop}>
          <View style={styles.sheet}>
            <Text style={styles.heading}>New event</Text>
            <TextInput style={styles.input} placeholder="Title" placeholderTextColor="#64748b" value={title} onChangeText={setTitle} autoFocus />
            <TextInput style={styles.input} placeholder="Location (optional)" placeholderTextColor="#64748b" value={location} onChangeText={setLocation} />
            <TextInput style={styles.input} placeholder="Hours from now" placeholderTextColor="#64748b" value={hoursAhead} onChangeText={setHoursAhead} keyboardType="decimal-pad" />
            <View style={styles.actions}>
              <TouchableOpacity onPress={() => setEventOpen(false)}><Text style={styles.cancel}>Cancel</Text></TouchableOpacity>
              <PrimaryButton label={saving ? 'Saving…' : 'Create'} onPress={submitEvent} disabled={!title.trim() || saving} />
            </View>
          </View>
        </KeyboardAvoidingView>
      </Modal>

      <Modal visible={remOpen} animationType="slide" transparent onRequestClose={() => setRemOpen(false)}>
        <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={styles.backdrop}>
          <View style={styles.sheet}>
            <Text style={styles.heading}>New reminder</Text>
            <TextInput style={styles.input} placeholder="Title" placeholderTextColor="#64748b" value={title} onChangeText={setTitle} autoFocus />
            <TextInput style={styles.input} placeholder="Hours from now" placeholderTextColor="#64748b" value={hoursAhead} onChangeText={setHoursAhead} keyboardType="decimal-pad" />
            <View style={styles.actions}>
              <TouchableOpacity onPress={() => setRemOpen(false)}><Text style={styles.cancel}>Cancel</Text></TouchableOpacity>
              <PrimaryButton label={saving ? 'Saving…' : 'Create'} onPress={submitReminder} disabled={!title.trim() || saving} />
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
  title: { color: '#f8fafc', fontSize: 15, fontWeight: '700' },
  meta: { flexDirection: 'row', flexWrap: 'wrap', alignItems: 'center', gap: 6, marginTop: 6 },
  sub: { color: '#94a3b8', fontSize: 12 },
  desc: { color: '#cbd5e1', fontSize: 13, marginTop: 6 },
  row: { flexDirection: 'row', alignItems: 'center', gap: 10 },
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
  actions: { flexDirection: 'row', justifyContent: 'flex-end', alignItems: 'center', gap: 16, marginTop: 8 },
  cancel: { color: '#94a3b8', fontWeight: '600' },
});
