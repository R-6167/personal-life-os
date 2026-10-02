import React, { useMemo, useState } from 'react';
import { ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { useAppData } from '../context/AppDataContext';
import { CreateHabitModal } from '../modals/CreateHabitModal';
import {
  Card,
  Chip,
  EmptyState,
  PrimaryButton,
  SectionHeader,
  formatDate,
} from '../components/ui';

export function HabitsScreen() {
  const { habitOccurrences, completeHabit, skipHabit } = useAppData();
  const [showCreate, setShowCreate] = useState(false);

  const open = useMemo(
    () => habitOccurrences.filter((h) => ['EXPECTED', 'PARTIAL', 'MISSED'].includes(h.status)),
    [habitOccurrences]
  );
  const done = useMemo(
    () => habitOccurrences.filter((h) => h.status === 'COMPLETED' || h.status === 'SKIPPED'),
    [habitOccurrences]
  );

  const completionRate =
    habitOccurrences.length === 0
      ? 0
      : Math.round(
          (habitOccurrences.filter((h) => h.status === 'COMPLETED').length /
            habitOccurrences.length) *
            100
        );

  return (
    <View style={{ flex: 1 }}>
      <ScrollView style={styles.scroll} contentContainerStyle={[styles.content, { paddingBottom: 88 }]}>
        <Card style={styles.hero}>
          <Text style={styles.heroLabel}>Today's completion</Text>
          <Text style={styles.heroValue}>{completionRate}%</Text>
          <Text style={styles.heroMeta}>
            {done.filter((h) => h.status === 'COMPLETED').length} of {habitOccurrences.length} habits
          </Text>
        </Card>

        <SectionHeader title="Still open" count={open.length} />
        {open.length === 0 ? (
          <EmptyState message="Nothing left — nice work." />
        ) : (
          open.map((habit) => (
            <Card key={habit.id}>
              <View style={styles.rowBetween}>
                <Text style={styles.title}>{habit.title}</Text>
                <Chip label={habit.status} tone="warn" />
              </View>
              <Text style={styles.meta}>
                {formatDate(habit.scheduledDate)}
                {habit.targetMinutes ? ` · ${habit.targetMinutes} min` : ''}
              </Text>
              <View style={styles.actions}>
                <PrimaryButton label="Skip" tone="ghost" onPress={() => skipHabit(habit.id)} />
                <PrimaryButton label="Complete" onPress={() => completeHabit(habit.id)} />
              </View>
            </Card>
          ))
        )}

        <SectionHeader title="Logged" count={done.length} />
        {done.map((habit) => (
          <Card key={habit.id}>
            <View style={styles.rowBetween}>
              <Text style={styles.title}>{habit.title}</Text>
              <Chip
                label={habit.status}
                tone={habit.status === 'COMPLETED' ? 'success' : 'neutral'}
              />
            </View>
          </Card>
        ))}
      </ScrollView>
      <TouchableOpacity style={styles.fab} onPress={() => setShowCreate(true)} activeOpacity={0.9}>
        <Text style={styles.fabText}>+</Text>
      </TouchableOpacity>
      <CreateHabitModal visible={showCreate} onClose={() => setShowCreate(false)} />
    </View>
  );
}

const styles = StyleSheet.create({
  scroll: { flex: 1 },
  content: { padding: 16, paddingBottom: 32 },
  hero: { alignItems: 'center', paddingVertical: 18, marginBottom: 14 },
  heroLabel: { color: '#94a3b8', fontSize: 12, fontWeight: '600', textTransform: 'uppercase' },
  heroValue: { color: '#f8fafc', fontSize: 36, fontWeight: '800', marginTop: 4 },
  heroMeta: { color: '#64748b', fontSize: 12, marginTop: 4 },
  rowBetween: { flexDirection: 'row', justifyContent: 'space-between', gap: 8 },
  title: { color: '#f8fafc', fontSize: 15, fontWeight: '700', flex: 1 },
  meta: { color: '#94a3b8', fontSize: 12, marginTop: 6 },
  actions: { flexDirection: 'row', gap: 8, marginTop: 12, justifyContent: 'flex-end' },
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
});
