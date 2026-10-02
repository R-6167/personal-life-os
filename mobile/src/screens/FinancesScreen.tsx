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
} from '../components/ui';

export function FinancesScreen() {
  const { accounts, billOccurrences, recentExpenses, payBill } = useAppData();

  const totalBalance = useMemo(
    () => accounts.reduce((sum, a) => sum + a.currentBalanceMinor, 0),
    [accounts]
  );

  const openBills = useMemo(
    () => billOccurrences.filter((b) => ['UPCOMING', 'DUE', 'OVERDUE'].includes(b.status)),
    [billOccurrences]
  );

  const obligations = useMemo(
    () => openBills.reduce((sum, b) => sum + b.expectedAmountMinor, 0),
    [openBills]
  );

  return (
    <ScrollView style={styles.scroll} contentContainerStyle={styles.content}>
      <Card style={styles.hero}>
        <Text style={styles.heroLabel}>Total balance</Text>
        <Text style={styles.heroValue}>{formatMoney(totalBalance)}</Text>
        <Text style={styles.heroMeta}>
          Open obligations {formatMoney(obligations)}
        </Text>
      </Card>

      <SectionHeader title="Accounts" count={accounts.length} />
      {accounts.map((account) => (
        <Card key={account.id}>
          <View style={styles.rowBetween}>
            <View>
              <Text style={styles.title}>{account.name}</Text>
              <Text style={styles.meta}>{account.type.replace('_', ' ')}</Text>
            </View>
            <Text style={styles.amount}>
              {formatMoney(account.currentBalanceMinor, account.currency)}
            </Text>
          </View>
        </Card>
      ))}

      <SectionHeader title="Bills due" count={openBills.length} />
      {openBills.length === 0 ? (
        <EmptyState message="No open bills." />
      ) : (
        openBills.map((bill) => (
          <Card key={bill.id}>
            <View style={styles.rowBetween}>
              <Text style={styles.title}>{bill.name}</Text>
              <Chip
                label={bill.status}
                tone={bill.status === 'OVERDUE' ? 'danger' : bill.status === 'DUE' ? 'warn' : 'info'}
              />
            </View>
            <Text style={styles.meta}>
              {formatMoney(bill.expectedAmountMinor, bill.currency)} · due {formatDate(bill.dueAt)}
              {bill.provider ? ` · ${bill.provider}` : ''}
            </Text>
            <View style={styles.actions}>
              <PrimaryButton label="Pay" onPress={() => payBill(bill.id)} />
            </View>
          </Card>
        ))
      )}

      <SectionHeader title="Recent expenses" count={recentExpenses.length} />
      {recentExpenses.map((exp) => (
        <Card key={exp.id}>
          <View style={styles.rowBetween}>
            <View style={{ flex: 1 }}>
              <Text style={styles.title}>{exp.description}</Text>
              <Text style={styles.meta}>
                {[exp.merchant, formatDate(exp.occurredAt)].filter(Boolean).join(' · ')}
              </Text>
            </View>
            <Text style={styles.expenseAmount}>
              −{formatMoney(exp.amountMinor, exp.currency)}
            </Text>
          </View>
        </Card>
      ))}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  scroll: { flex: 1 },
  content: { padding: 16, paddingBottom: 32 },
  hero: { alignItems: 'center', paddingVertical: 18, marginBottom: 14 },
  heroLabel: { color: '#94a3b8', fontSize: 12, fontWeight: '600', textTransform: 'uppercase' },
  heroValue: { color: '#f8fafc', fontSize: 32, fontWeight: '800', marginTop: 4 },
  heroMeta: { color: '#64748b', fontSize: 12, marginTop: 4 },
  rowBetween: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', gap: 8 },
  title: { color: '#f8fafc', fontSize: 15, fontWeight: '700' },
  meta: { color: '#94a3b8', fontSize: 12, marginTop: 4 },
  amount: { color: '#86efac', fontSize: 16, fontWeight: '700' },
  expenseAmount: { color: '#fca5a5', fontSize: 14, fontWeight: '700' },
  actions: { flexDirection: 'row', gap: 8, marginTop: 12, justifyContent: 'flex-end' },
});
