import React, { useMemo, useState } from 'react';
import {
  ActivityIndicator,
  SafeAreaView,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import { AppDataProvider, useAppData } from './src/context/AppDataContext';
import { useAppDataSQLite } from './src/hooks/useAppDataSQLite';
import { TodayScreen } from './src/screens/TodayScreen';
import { TasksScreen } from './src/screens/TasksScreen';
import { HabitsScreen } from './src/screens/HabitsScreen';
import { FinancesScreen } from './src/screens/FinancesScreen';
import { GoalsScreen } from './src/screens/GoalsScreen';
import { ProjectsScreen } from './src/screens/ProjectsScreen';
import { SettingsScreen } from './src/screens/SettingsScreen';
import { CaptureScreen } from './src/screens/CaptureScreen';
import { NotesScreen } from './src/screens/NotesScreen';
import { CalendarScreen } from './src/screens/CalendarScreen';

type Screen = 'Today' | 'Capture' | 'Tasks' | 'Habits' | 'Notes' | 'Calendar' | 'Goals' | 'Projects' | 'Finances' | 'Settings';

const tabs: Screen[] = ['Today', 'Capture', 'Tasks', 'Habits', 'Notes', 'Calendar', 'Goals', 'Projects', 'Finances', 'Settings'];

const greetings = () => {
  const hour = new Date().getHours();
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
};

function AppContent() {
  const [activeScreen, setActiveScreen] = useState<Screen>('Today');
  const eyebrow = useMemo(() => greetings(), []);
  const { ready, error } = useAppData();

  const renderScreen = () => {
    switch (activeScreen) {
      case 'Today':
        return <TodayScreen />;
      case 'Capture':
        return <CaptureScreen />;
      case 'Tasks':
        return <TasksScreen />;
      case 'Habits':
        return <HabitsScreen />;
      case 'Notes':
        return <NotesScreen />;
      case 'Calendar':
        return <CalendarScreen />;
      case 'Goals':
        return <GoalsScreen />;
      case 'Projects':
        return <ProjectsScreen />;
      case 'Finances':
        return <FinancesScreen />;
      case 'Settings':
        return <SettingsScreen />;
      default:
        return <TodayScreen />;
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="light-content" backgroundColor="#0f172a" />

      <View style={styles.headerCard}>
        <Text style={styles.eyebrow}>{eyebrow}</Text>
        <Text style={styles.title}>{activeScreen}</Text>
        <Text style={styles.sub}>Offline · local SQLite</Text>
      </View>

      <View style={styles.screenContainer}>
        {!ready ? (
          <View style={styles.center}>
            <ActivityIndicator color="#60a5fa" />
            <Text style={styles.loadingText}>Opening local database…</Text>
          </View>
        ) : error ? (
          <View style={styles.center}>
            <Text style={styles.errorText}>{error}</Text>
          </View>
        ) : (
          renderScreen()
        )}
      </View>

      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        style={styles.tabBarScroll}
        contentContainerStyle={styles.tabBar}
      >
        {tabs.map((tab) => (
          <TouchableOpacity
            key={tab}
            onPress={() => setActiveScreen(tab)}
            style={[styles.tabButton, activeScreen === tab && styles.activeTabButton]}
            activeOpacity={0.85}
          >
            <Text style={[styles.tabText, activeScreen === tab && styles.activeTabText]}>{tab}</Text>
          </TouchableOpacity>
        ))}
      </ScrollView>
    </SafeAreaView>
  );
}

function App() {
  const appData = useAppDataSQLite();

  return (
    <AppDataProvider value={appData}>
      <AppContent />
    </AppDataProvider>
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
    paddingTop: 12,
    paddingBottom: 12,
  },
  eyebrow: {
    color: '#94a3b8',
    fontSize: 11,
    letterSpacing: 1.1,
    textTransform: 'uppercase',
  },
  title: {
    color: '#f8fafc',
    fontSize: 28,
    fontWeight: '700',
    marginTop: 6,
  },
  sub: {
    color: '#64748b',
    fontSize: 11,
    marginTop: 4,
    fontWeight: '600',
  },
  screenContainer: {
    flex: 1,
    backgroundColor: '#0f172a',
  },
  center: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
  },
  loadingText: { color: '#94a3b8', marginTop: 12, fontSize: 13 },
  errorText: { color: '#fca5a5', textAlign: 'center', fontSize: 13 },
  tabBarScroll: {
    maxHeight: 64,
    borderTopWidth: 1,
    borderTopColor: '#1f2937',
    backgroundColor: '#0f172a',
  },
  tabBar: {
    flexDirection: 'row',
    paddingHorizontal: 10,
    paddingVertical: 10,
    alignItems: 'center',
  },
  tabButton: {
    paddingVertical: 10,
    paddingHorizontal: 14,
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
});

export default App;
