import React, { useMemo, useState } from 'react';
import { SafeAreaView, StatusBar, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { AppDataProvider } from './src/context/AppDataContext';
import { useAppDataMock } from './src/hooks/useAppDataMock';
import { TodayScreen } from './src/screens/TodayScreen';
import { TasksScreen } from './src/screens/TasksScreen';
import { HabitsScreen } from './src/screens/HabitsScreen';
import { FinancesScreen } from './src/screens/FinancesScreen';

type Screen = 'Today' | 'Tasks' | 'Habits' | 'Finances';

const tabs: Screen[] = ['Today', 'Tasks', 'Habits', 'Finances'];

const greetings = () => {
  const hour = new Date().getHours();
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
};

function AppContent() {
  const [activeScreen, setActiveScreen] = useState<Screen>('Today');
  const eyebrow = useMemo(() => greetings(), []);

  const renderScreen = () => {
    switch (activeScreen) {
      case 'Today':
        return <TodayScreen />;
      case 'Tasks':
        return <TasksScreen />;
      case 'Habits':
        return <HabitsScreen />;
      case 'Finances':
        return <FinancesScreen />;
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
      </View>

      <View style={styles.screenContainer}>{renderScreen()}</View>

      <View style={styles.tabBar}>
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
      </View>
    </SafeAreaView>
  );
}

function App() {
  const appData = useAppDataMock();

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
  screenContainer: {
    flex: 1,
    backgroundColor: '#0f172a',
  },
  tabBar: {
    flexDirection: 'row',
    paddingHorizontal: 12,
    paddingVertical: 10,
    backgroundColor: '#0f172a',
    borderTopWidth: 1,
    borderTopColor: '#1f2937',
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
});

export default App;
