import React, { useMemo } from 'react';
import { ScrollView, StyleSheet, Text, View } from 'react-native';
import { useAppData } from '../context/AppDataContext';
import {
  Card,
  Chip,
  EmptyState,
  PrimaryButton,
  SectionHeader,
  formatDate,
  formatMoney,
  formatTime,
} from '../components/ui';

export function TodayScreen() {
  const {
    tasks,
    habitOccurrences,
    billOccurrences,
    recentActivity,
    completeTask,
    startTask,
    completeHabit,
    skipHabit,
    payBill,
  } = useAppData();

  const openTasks = useMemo(
    () => tasks.filter((t) => !['COMPLETED', 'CANCELLED'].includes(t.status)),
    [tasks]
  );
  const dueHabits = useMemo(
    () => habitOccurrences.filter((h) => h.status === 'EXPECTED' || h.status === 'PARTIAL'),
    [habitOccurrences]
  );
  const openBills = useMemo(
    () => billOccurrences.filter((b) => ['UPCOMING', 'DUE', 'OVERDUE'].includes(b.status)),
    [billOccurrences]
  );
  const overdue = useMemo(
    () => openTasks.filter((t) => t.dueAt && t.dueAt < Date.now()),
    [openTasks]
  );

  return (
    <ScrollView style={styles.scroll} contentContainerStyle={styles.content}>
      <View style={styles.summaryRow}>
        <SummaryTile label="Tasks" value={String(openTasks.length)} />
        <SummaryTile label="Habits" value={String(dueHabits.length)} />
        <SummaryTile label="Bills" value={String(openBills.length)} />
        <SummaryTile label="Overdue" value={String(overdue.length)} tone="danger" />
      </View>

      <SectionHeader title="Focus tasks" count={openTasks.length} />
      {openTasks.length === 0 ? (
        <EmptyState message="No open tasks for today." />
      ) : (
        openTasks.slice(0, 5).map((task) => (
          <Card key={task.id}>
            <View style={styles.rowBetween}>
              <Text style={styles.itemTitle}>{task.title}</Text>
              <Chip
                label={task.status.replace('_', ' ')}
                tone={task.status === 'IN_PROGRESS' ? 'info' : 'neutral'}
              />
            </View>
            <Text style={styles.meta}>
              {[task.projectTitle, task.dueAt ? formatDate(task.dueAt) : null, task.dueAt ? formatTime(task.dueAt) : null]
                .filter(Boolean)
                .join(' · ')}
            </Text>
            <View style={styles.actions}>
              {task.status !== 'IN_PROGRESS' && task.status !== 'COMPLETED' ? (
                <PrimaryButton label="Start" tone="ghost" onPress={() => startTask(task.id)} />
              ) : null}
              <PrimaryButton label="Complete" onPress={() => completeTask(task.id)} />
            </View>
          </Card>
        ))
      )}

      <SectionHeader title="Habits due" count={dueHabits.length} />
      {dueHabits.length === 0 ? (
        <EmptyState message="All habits done for today." />
      ) : (
        dueHabits.map((habit) => (
          <Card key={habit.id}>
            <View style={styles.rowBetween}>
              <Text style={styles.itemTitle}>{habit.title}</Text>
              <Chip label={habit.status} tone="warn" />
            </View>
            {habit.targetMinutes ? (
              <Text style={styles.meta}>{habit.targetMinutes} min target</Text>
            ) : null}
            <View style={styles.actions}>
              <PrimaryButton label="Skip" tone="ghost" onPress={() => skipHabit(habit.id)} />
              <PrimaryButton label="Done" onPress={() => completeHabit(habit.id)} />
            </View>
          </Card>
        ))
      )}

      <SectionHeader title="Bills" count={openBills.length} />
      {openBills.length === 0 ? (
        <EmptyState message="No upcoming bills." />
      ) : (
        openBills.map((bill) => (
          <Card key={bill.id}>
            <View style={styles.rowBetween}>
              <Text style={styles.itemTitle}>{bill.name}</Text>
              <Chip
                label={bill.status}
                tone={bill.status === 'OVERDUE' ? 'danger' : bill.status === 'DUE' ? 'warn' : 'neutral'}
              />
            </View>
            <Text style={styles.meta}>
              {formatMoney(bill.expectedAmountMinor, bill.currency)} · due {formatDate(bill.dueAt)}
            </Text>
            <View style={styles.actions}>
              <PrimaryButton label="Mark paid" onPress={() => payBill(bill.id)} />
            </View>
          </Card>
        ))
      )}

      <SectionHeader title="Recent activity" count={recentActivity.length} />
      {recentActivity.slice(0, 8).map((a) => (
        <Card key={a.id} style={styles.activityCard}>
          <Text style={styles.activityType}>{a.eventType}</Text>
          <Text style={styles.itemTitle}>{a.title}</Text>
          <Text style={styles.meta}>{formatTime(a.occurredAt)}</Text>
        </Card>
      ))}
    </ScrollView>
  );
}

function SummaryTile({
  label,
  value,
  tone,
}: {
  label: string;
  value: string;
  tone?: 'danger';
}) {
  return (
    <View style={[styles.tile, tone === 'danger' && styles.tileDanger]}>
      <Text style={[styles.tileValue, tone === 'danger' && styles.tileValueDanger]}>{value}</Text>
      <Text style={styles.tileLabel}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  scroll: { flex: 1 },
  content: { padding: 16, paddingBottom: 32 },
  summaryRow: { flexDirection: 'row', gap: 8, marginBottom: 12 },
  tile: {
    flex: 1,
    backgroundColor: '#111827',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#1f2937',
    paddingVertical: 12,
    alignItems: 'center',
  },
  tileDanger: { borderColor: '#7f1d1d', backgroundColor: '#1c1010' },
  tileValue: { color: '#f8fafc', fontSize: 18, fontWeight: '800' },
  tileValueDanger: { color: '#fca5a5' },
  tileLabel: { color: '#94a3b8', fontSize: 11, marginTop: 2, fontWeight: '600' },
  rowBetween: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', gap: 8 },
  itemTitle: { color: '#f1f5f9', fontSize: 15, fontWeight: '600', flex: 1 },
  meta: { color: '#94a3b8', fontSize: 12, marginTop: 6 },
  actions: { flexDirection: 'row', gap: 8, marginTop: 12, justifyContent: 'flex-end' },
  activityCard: { paddingVertical: 10 },
  activityType: { color: '#60a5fa', fontSize: 11, fontWeight: '700', marginBottom: 2 },
});
