import { StatusBar } from 'expo-status-bar';
import React, { useMemo } from 'react';
import {
  FlatList,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  View,
  TouchableOpacity,
} from 'react-native';

type TaskItem = {
  id: string;
  title: string;
  status: string;
  dueAt: string;
  priority: number;
};

type HabitItem = {
  id: string;
  title: string;
  status: string;
  scheduledDate: string;
};

type BillItem = {
  id: string;
  name: string;
  dueAt: string;
  amount: string;
};

const tasks: TaskItem[] = [
  { id: 't1', title: 'Finish project brief', status: 'IN_PROGRESS', dueAt: 'Today', priority: 3 },
  { id: 't2', title: 'Book dentist appointment', status: 'PLANNED', dueAt: 'Tomorrow', priority: 2 },
  { id: 't3', title: 'Review monthly budget', status: 'WAITING', dueAt: 'This week', priority: 1 },
];

const habits: HabitItem[] = [
  { id: 'h1', title: 'Morning run', status: 'EXPECTED', scheduledDate: 'Today' },
  { id: 'h2', title: 'Read 20 pages', status: 'EXPECTED', scheduledDate: 'Today' },
  { id: 'h3', title: 'Stretch routine', status: 'PARTIAL', scheduledDate: 'Today' },
];

const bills: BillItem[] = [
  { id: 'b1', name: 'Internet', dueAt: 'Today', amount: 'KES 2,500' },
  { id: 'b2', name: 'Rent', dueAt: 'Tomorrow', amount: 'KES 18,000' },
  { id: 'b3', name: 'Streaming', dueAt: 'This week', amount: 'KES 1,200' },
];

function SectionHeader({ title }: { title: string }) {
  return <Text style={styles.sectionTitle}>{title}</Text>;
}

function App() {
  const stats = useMemo(
    () => ({
      tasks: tasks.length,
      habits: habits.length,
      bills: bills.length,
    }),
    []
  );

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar style="light" />
      <ScrollView contentContainerStyle={styles.content}>
        <View style={styles.headerCard}>
          <Text style={styles.eyebrow}>Good morning</Text>
          <Text style={styles.title}>Today</Text>
          <View style={styles.statRow}>
            <View style={styles.statBox}>
              <Text style={styles.statValue}>{stats.tasks}</Text>
              <Text style={styles.statLabel}>Tasks</Text>
            </View>
            <View style={styles.statBox}>
              <Text style={styles.statValue}>{stats.habits}</Text>
              <Text style={styles.statLabel}>Habits</Text>
            </View>
            <View style={styles.statBox}>
              <Text style={styles.statValue}>{stats.bills}</Text>
              <Text style={styles.statLabel}>Bills</Text>
            </View>
          </View>
        </View>

        <View style={styles.section}>
          <SectionHeader title="Tasks" />
          {tasks.map((task) => (
            <TouchableOpacity key={task.id} style={styles.card} activeOpacity={0.8}>
              <View style={styles.cardTopRow}>
                <Text style={styles.cardTitle}>{task.title}</Text>
                <Text style={styles.priority}>P{task.priority}</Text>
              </View>
              <Text style={styles.meta}>{task.status} • {task.dueAt}</Text>
            </TouchableOpacity>
          ))}
        </View>

        <View style={styles.section}>
          <SectionHeader title="Habits" />
          {habits.map((habit) => (
            <View key={habit.id} style={styles.card}>
              <Text style={styles.cardTitle}>{habit.title}</Text>
              <Text style={styles.meta}>{habit.status} • {habit.scheduledDate}</Text>
            </View>
          ))}
        </View>

        <View style={styles.section}>
          <SectionHeader title="Bills" />
          {bills.map((bill) => (
            <View key={bill.id} style={styles.card}>
              <View style={styles.cardTopRow}>
                <Text style={styles.cardTitle}>{bill.name}</Text>
                <Text style={styles.amount}>{bill.amount}</Text>
              </View>
              <Text style={styles.meta}>{bill.dueAt}</Text>
            </View>
          ))}
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0f172a',
  },
  content: {
    padding: 16,
    paddingBottom: 40,
  },
  headerCard: {
    backgroundColor: '#111827',
    borderRadius: 20,
    padding: 20,
    marginBottom: 20,
    borderWidth: 1,
    borderColor: '#1f2937',
  },
  eyebrow: {
    color: '#94a3b8',
    fontSize: 12,
    textTransform: 'uppercase',
    letterSpacing: 1.1,
  },
  title: {
    color: '#f8fafc',
    fontSize: 32,
    fontWeight: '700',
    marginTop: 8,
  },
  statRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 18,
  },
  statBox: {
    flex: 1,
    backgroundColor: '#1e293b',
    borderRadius: 12,
    paddingVertical: 14,
    marginHorizontal: 4,
    alignItems: 'center',
  },
  statValue: {
    color: '#f8fafc',
    fontSize: 24,
    fontWeight: '700',
  },
  statLabel: {
    color: '#94a3b8',
    fontSize: 12,
    marginTop: 4,
  },
  section: {
    marginBottom: 22,
  },
  sectionTitle: {
    color: '#e2e8f0',
    fontSize: 18,
    fontWeight: '700',
    marginBottom: 12,
  },
  card: {
    backgroundColor: '#111827',
    borderRadius: 14,
    padding: 14,
    marginBottom: 10,
    borderWidth: 1,
    borderColor: '#1f2937',
  },
  cardTopRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 6,
  },
  cardTitle: {
    color: '#f8fafc',
    fontSize: 16,
    fontWeight: '600',
    flex: 1,
    marginRight: 10,
  },
  priority: {
    color: '#fbbf24',
    fontWeight: '700',
  },
  amount: {
    color: '#34d399',
    fontWeight: '700',
  },
  meta: {
    color: '#94a3b8',
    fontSize: 12,
  },
});

export default App;
