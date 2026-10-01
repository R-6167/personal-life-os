import React, { useMemo, useState } from 'react';
import {
  FlatList,
  SafeAreaView,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';

type Screen = 'Today' | 'Tasks' | 'Habits' | 'Finances';

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

type DashboardContext = {
  tasks: TaskItem[];
  habits: HabitItem[];
  bills: BillItem[];
};

const tabs: Screen[] = ['Today', 'Tasks', 'Habits', 'Finances'];

const dashboardData: DashboardContext = {
  tasks: [
    { id: 't1', title: 'Finish project brief', status: 'IN_PROGRESS', dueAt: 'Today', priority: 3 },
    { id: 't2', title: 'Book dentist appointment', status: 'PLANNED', dueAt: 'Tomorrow', priority: 2 },
    { id: 't3', title: 'Review monthly budget', status: 'WAITING', dueAt: 'This week', priority: 1 },
    { id: 't4', title: 'Clean workspace', status: 'INBOX', dueAt: 'Later', priority: 2 },
  ],
  habits: [
    { id: 'h1', title: 'Morning run', status: 'EXPECTED', scheduledDate: 'Today' },
    { id: 'h2', title: 'Read 20 pages', status: 'EXPECTED', scheduledDate: 'Today' },
    { id: 'h3', title: 'Stretch routine', status: 'PARTIAL', scheduledDate: 'Today' },
    { id: 'h4', title: 'Drink water', status: 'EXPECTED', scheduledDate: 'Today' },
  ],
  bills: [
    { id: 'b1', name: 'Internet', dueAt: 'Today', amount: 'KES 2,500' },
    { id: 'b2', name: 'Rent', dueAt: 'Tomorrow', amount: 'KES 18,000' },
    { id: 'b3', name: 'Streaming', dueAt: 'This week', amount: 'KES 1,200' },
  ],
};

function App() {
  const [activeTab, setActiveTab] = useState<Screen>('Today');

  const stats = useMemo(
    () => ({
      tasks: dashboardData.tasks.length,
      habits: dashboardData.habits.length,
      bills: dashboardData.bills.length,
    }),
    []
  );

  const renderTaskCard = ({ item }: { item: TaskItem }) => (
    <TouchableOpacity key={item.id} style={styles.card} activeOpacity={0.8}>
      <View style={styles.rowBetween}>
        <Text style={styles.cardTitle}>{item.title}</Text>
        <Text style={styles.priority}>P{item.priority}</Text>
      </View>
      <Text style={styles.meta}>{item.status} • {item.dueAt}</Text>
    </TouchableOpacity>
  );

  const renderHabitCard = ({ item }: { item: HabitItem }) => (
    <View key={item.id} style={styles.card}>
      <Text style={styles.cardTitle}>{item.title}</Text>
      <Text style={styles.meta}>{item.status} • {item.scheduledDate}</Text>
    </View>
  );

  const renderBillCard = ({ item }: { item: BillItem }) => (
    <View key={item.id} style={styles.card}>
      <View style={styles.rowBetween}>
        <Text style={styles.cardTitle}>{item.name}</Text>
        <Text style={styles.amount}>{item.amount}</Text>
      </View>
      <Text style={styles.meta}>{item.dueAt}</Text>
    </View>
  );

  const contentByTab: Record<Screen, React.ReactNode> = {
    Today: (
      <ScrollView contentContainerStyle={styles.sectionContent}>
        <View style={styles.section}>
          <Text style={styles.sectionLabel}>Tasks</Text>
          {dashboardData.tasks.slice(0, 3).map((item) => renderTaskCard({ item }))}
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionLabel}>Habits</Text>
          {dashboardData.habits.slice(0, 3).map((item) => renderHabitCard({ item }))}
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionLabel}>Bills</Text>
          {dashboardData.bills.slice(0, 3).map((item) => renderBillCard({ item }))}
        </View>
      </ScrollView>
    ),
    Tasks: (
      <View style={styles.listWrap}>
        <FlatList
          data={dashboardData.tasks}
          keyExtractor={(item) => item.id}
          renderItem={renderTaskCard}
          contentContainerStyle={styles.listContent}
          showsVerticalScrollIndicator={false}
        />
      </View>
    ),
    Habits: (
      <View style={styles.listWrap}>
        <FlatList
          data={dashboardData.habits}
          keyExtractor={(item) => item.id}
          renderItem={renderHabitCard}
          contentContainerStyle={styles.listContent}
          showsVerticalScrollIndicator={false}
        />
      </View>
    ),
    Finances: (
      <View style={styles.listWrap}>
        <FlatList
          data={dashboardData.bills}
          keyExtractor={(item) => item.id}
          renderItem={renderBillCard}
          contentContainerStyle={styles.listContent}
          showsVerticalScrollIndicator={false}
        />
      </View>
    ),
  };

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="light-content" backgroundColor="#0f172a" />

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

      <View style={styles.tabRow}>
        {tabs.map((tab) => (
          <TouchableOpacity
            key={tab}
            onPress={() => setActiveTab(tab)}
            style={[styles.tabButton, activeTab === tab && styles.activeTabButton]} 
            activeOpacity={0.85}
          >
            <Text style={[styles.tabText, activeTab === tab && styles.activeTabText]}>{tab}</Text>
          </TouchableOpacity>
        ))}
      </View>

      {contentByTab[activeTab]}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0f172a',
  },
  headerCard: {
    backgroundColor: '#111827',
    borderBottomWidth: 1,
    borderBottomColor: '#1f2937',
    paddingHorizontal: 20,
    paddingTop: 20,
    paddingBottom: 18,
  },
  eyebrow: {
    color: '#94a3b8',
    fontSize: 11,
    letterSpacing: 1.1,
    textTransform: 'uppercase',
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
    paddingVertical: 12,
    marginHorizontal: 4,
    alignItems: 'center',
  },
  statValue: {
    color: '#f8fafc',
    fontSize: 22,
    fontWeight: '700',
  },
  statLabel: {
    color: '#94a3b8',
    fontSize: 11,
    marginTop: 4,
  },
  tabRow: {
    flexDirection: 'row',
    paddingHorizontal: 12,
    paddingVertical: 12,
    backgroundColor: '#0f172a',
    borderBottomWidth: 1,
    borderBottomColor: '#1f2937',
  },
  tabButton: {
    flex: 1,
    paddingVertical: 10,
    borderRadius: 10,
    marginHorizontal: 4,
    alignItems: 'center',
    backgroundColor: '#111827',
    borderWidth: 1,
    borderColor: '#1f2937',
  },
  activeTabButton: {
    backgroundColor: '#1d4ed8',
    borderColor: '#60a5fa',
  },
  tabText: {
    color: '#cbd5e1',
    fontSize: 12,
    fontWeight: '600',
  },
  activeTabText: {
    color: '#eff6ff',
  },
  sectionContent: {
    padding: 16,
    paddingBottom: 32,
  },
  section: {
    marginBottom: 18,
  },
  sectionLabel: {
    color: '#e2e8f0',
    fontSize: 16,
    fontWeight: '700',
    marginBottom: 10,
  },
  card: {
    backgroundColor: '#111827',
    borderRadius: 14,
    padding: 14,
    marginBottom: 10,
    borderWidth: 1,
    borderColor: '#1f2937',
  },
  rowBetween: {
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
    marginRight: 8,
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
  listWrap: {
    flex: 1,
    paddingHorizontal: 16,
    paddingTop: 12,
  },
  listContent: {
    paddingBottom: 24,
  },
});

export default App;
