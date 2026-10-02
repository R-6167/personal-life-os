import React, { useMemo, useState } from 'react';
import { ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { useAppData } from '../context/AppDataContext';
import type { TaskStatus } from '../types/app-data';
import {
  Card,
  Chip,
  EmptyState,
  PrimaryButton,
  SectionHeader,
  formatDate,
  formatTime,
} from '../components/ui';

const FILTERS: Array<'ALL' | TaskStatus> = [
  'ALL',
  'INBOX',
  'PLANNED',
  'IN_PROGRESS',
  'WAITING',
  'COMPLETED',
];

export function TasksScreen() {
  const { tasks, completeTask, startTask } = useAppData();
  const [filter, setFilter] = useState<(typeof FILTERS)[number]>('ALL');

  const filtered = useMemo(() => {
    if (filter === 'ALL') return tasks;
    return tasks.filter((t) => t.status === filter);
  }, [tasks, filter]);

  return (
    <ScrollView style={styles.scroll} contentContainerStyle={styles.content}>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.filters}>
        {FILTERS.map((f) => (
          <TouchableOpacity
            key={f}
            onPress={() => setFilter(f)}
            style={[styles.filterChip, filter === f && styles.filterChipActive]}
          >
            <Text style={[styles.filterText, filter === f && styles.filterTextActive]}>
              {f === 'ALL' ? 'All' : f.replace('_', ' ')}
            </Text>
          </TouchableOpacity>
        ))}
      </ScrollView>

      <SectionHeader title="Tasks" count={filtered.length} />
      {filtered.length === 0 ? (
        <EmptyState message="No tasks in this filter." />
      ) : (
        filtered.map((task) => (
          <Card key={task.id}>
            <View style={styles.rowBetween}>
              <Text style={styles.title}>{task.title}</Text>
              <Chip
                label={task.status.replace('_', ' ')}
                tone={
                  task.status === 'COMPLETED'
                    ? 'success'
                    : task.status === 'IN_PROGRESS'
                      ? 'info'
                      : task.status === 'WAITING'
                        ? 'warn'
                        : 'neutral'
                }
              />
            </View>
            {task.description ? <Text style={styles.desc}>{task.description}</Text> : null}
            <Text style={styles.meta}>
              {[
                task.projectTitle,
                task.dueAt ? `${formatDate(task.dueAt)} ${formatTime(task.dueAt)}` : null,
                task.estimatedMinutes ? `${task.estimatedMinutes}m` : null,
                `P${task.priority}`,
              ]
                .filter(Boolean)
                .join(' · ')}
            </Text>
            {task.status !== 'COMPLETED' && task.status !== 'CANCELLED' ? (
              <View style={styles.actions}>
                {task.status !== 'IN_PROGRESS' ? (
                  <PrimaryButton label="Start" tone="ghost" onPress={() => startTask(task.id)} />
                ) : null}
                <PrimaryButton label="Complete" onPress={() => completeTask(task.id)} />
              </View>
            ) : null}
          </Card>
        ))
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  scroll: { flex: 1 },
  content: { padding: 16, paddingBottom: 32 },
  filters: { marginBottom: 8, maxHeight: 40 },
  filterChip: {
    paddingHorizontal: 12,
    paddingVertical: 7,
    borderRadius: 999,
    backgroundColor: '#111827',
    borderWidth: 1,
    borderColor: '#1f2937',
    marginRight: 8,
  },
  filterChipActive: { backgroundColor: '#1d4ed8', borderColor: '#60a5fa' },
  filterText: { color: '#94a3b8', fontSize: 12, fontWeight: '600' },
  filterTextActive: { color: '#eff6ff' },
  rowBetween: { flexDirection: 'row', justifyContent: 'space-between', gap: 8 },
  title: { color: '#f8fafc', fontSize: 15, fontWeight: '700', flex: 1 },
  desc: { color: '#cbd5e1', fontSize: 13, marginTop: 6 },
  meta: { color: '#94a3b8', fontSize: 12, marginTop: 8 },
  actions: { flexDirection: 'row', gap: 8, marginTop: 12, justifyContent: 'flex-end' },
});
