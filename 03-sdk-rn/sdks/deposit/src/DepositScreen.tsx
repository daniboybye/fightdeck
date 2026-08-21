import React, { useMemo, useState } from 'react';
import {
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { notifyNative } from '../../core/src/runtime/RuntimeRegistry';
import { formatCurrency, money, parseMoney } from '../../core/src/fightcore/money';
import { parseThemeJSON } from '../../core/src/ui/theme';

const MIN_DEPOSIT = parseMoney('10.00');
const MAX_DEPOSIT = parseMoney('2000.00');

const METHODS = [
  { id: 'card', title: 'Card', fee: 'Instant · 0% fee', rate: 0 },
  { id: 'bank', title: 'Bank transfer', fee: '1–2 days · 0% fee', rate: 0 },
  { id: 'wallet', title: 'Wallet', fee: 'Instant · 1% fee', rate: 0.01 },
];

export function DepositScreen(props: Record<string, unknown>) {
  const theme = useMemo(
    () => parseThemeJSON(String(props.themeJSON ?? '{}')),
    [props.themeJSON],
  );
  const balance = parseMoney(String(props.currentBalance ?? '0'));
  const [amountText, setAmountText] = useState('');
  const [methodId, setMethodId] = useState('card');
  const [didSucceed, setDidSucceed] = useState(false);

  const styles = makeStyles(theme);
  const amount = parseMoney(amountText || '0');
  const method = METHODS.find((m) => m.id === methodId) ?? METHODS[0];
  const fee = money(amount.times(method.rate));
  const total = money(amount.plus(fee));
  const amountError = (() => {
    if (amountText.length === 0) {
      return null;
    }
    if (amount.lessThan(MIN_DEPOSIT)) {
      return 'Minimum deposit is €10';
    }
    if (amount.greaterThan(MAX_DEPOSIT)) {
      return 'Maximum deposit is €2,000';
    }
    return null;
  })();

  const done = () => {
    notifyNative('deposit', { type: 'completed', amount: formatCurrency(amount) });
  };

  if (didSucceed) {
    return (
      <View style={styles.root}>
        <Text style={styles.successIcon}>✓</Text>
        <Text style={styles.title}>Deposit successful</Text>
        <Text style={styles.secondary}>
          New balance: {formatCurrency(money(balance.plus(amount)))}
        </Text>
        <Pressable style={styles.primaryButton} onPress={done}>
          <Text style={styles.primaryLabel}>Done</Text>
        </Pressable>
      </View>
    );
  }

  return (
    <ScrollView style={styles.root} contentContainerStyle={styles.content}>
      <Text style={styles.secondary}>Balance: {formatCurrency(balance)}</Text>

      <TextInput
        style={styles.amountInput}
        keyboardType="decimal-pad"
        placeholder="€0.00"
        placeholderTextColor={theme.colors.textSecondary}
        value={amountText}
        onChangeText={setAmountText}
      />
      {amountError ? <Text style={styles.error}>{amountError}</Text> : null}
      <View style={styles.chipRow}>
        {[10, 25, 50, 100].map((chip) => (
          <Pressable key={chip} style={styles.chip} onPress={() => setAmountText(String(chip))}>
            <Text style={styles.chipLabel}>€{chip}</Text>
          </Pressable>
        ))}
      </View>

      {METHODS.map((item) => (
        <Pressable
          key={item.id}
          style={[styles.methodRow, methodId === item.id && styles.methodSelected]}
          onPress={() => setMethodId(item.id)}
        >
          <Text style={styles.methodRadio}>{methodId === item.id ? '◉' : '○'}</Text>
          <View style={{ flex: 1 }}>
            <Text style={styles.body}>{item.title}</Text>
            <Text style={styles.secondary}>{item.fee}</Text>
          </View>
        </Pressable>
      ))}

      <View style={styles.summary}>
        <SummaryRow label="Amount" value={formatCurrency(amount)} styles={styles} />
        <SummaryRow label="Method" value={method.title} styles={styles} />
        <SummaryRow label="Fee" value={formatCurrency(fee)} styles={styles} />
        <SummaryRow label="Total" value={formatCurrency(total)} styles={styles} />
      </View>

      <Pressable
        style={[styles.primaryButton, (amountError != null || amountText.length === 0) && styles.disabled]}
        disabled={amountError != null || amountText.length === 0}
        onPress={() => setDidSucceed(true)}
      >
        <Text style={styles.primaryLabel}>Confirm deposit</Text>
      </Pressable>
    </ScrollView>
  );
}

function SummaryRow({
  label,
  value,
  styles,
}: {
  label: string;
  value: string;
  styles: ReturnType<typeof makeStyles>;
}) {
  return (
    <View style={styles.summaryRow}>
      <Text style={styles.secondary}>{label}</Text>
      <Text style={styles.body}>{value}</Text>
    </View>
  );
}

function makeStyles(theme: ReturnType<typeof parseThemeJSON>) {
  const c = theme.colors;
  const s = theme.spacing;
  const r = theme.radius;
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: c.background ?? '#0B0E14' },
    content: { padding: s.lg ?? 16, gap: s.lg ?? 16 },
    title: { color: c.textPrimary ?? '#F5F7FA', fontSize: theme.fontSize.title ?? 22, fontWeight: '700' },
    body: { color: c.textPrimary ?? '#F5F7FA', fontSize: theme.fontSize.body ?? 15 },
    secondary: { color: c.textSecondary ?? '#9AA5B8', fontSize: theme.fontSize.body ?? 15 },
    error: { color: c.negative ?? '#F2545B', fontSize: theme.fontSize.caption ?? 12 },
    successIcon: { color: c.positive ?? '#3DD68C', fontSize: 64, textAlign: 'center' },
    amountInput: {
      color: c.textPrimary ?? '#F5F7FA',
      fontSize: theme.fontSize.display ?? 34,
      fontWeight: '700',
      padding: s.lg ?? 16,
      backgroundColor: c.surface ?? '#141922',
      borderRadius: r.lg ?? 16,
    },
    chipRow: { flexDirection: 'row', gap: s.sm ?? 8 },
    chip: {
      paddingHorizontal: s.lg ?? 16,
      paddingVertical: s.sm ?? 8,
      borderRadius: r.full ?? 999,
      backgroundColor: c.surfaceElevated ?? '#1C2230',
    },
    chipLabel: { color: c.accent ?? '#E8B33C' },
    methodRow: {
      flexDirection: 'row',
      alignItems: 'center',
      gap: s.md ?? 12,
      padding: s.lg ?? 16,
      borderRadius: r.lg ?? 16,
      backgroundColor: c.surface ?? '#141922',
    },
    methodSelected: { borderWidth: 2, borderColor: c.accent ?? '#E8B33C' },
    methodRadio: { color: c.accent ?? '#E8B33C', fontSize: 20 },
    summary: {
      gap: s.sm ?? 8,
      padding: s.lg ?? 16,
      backgroundColor: c.surfaceElevated ?? '#1C2230',
      borderRadius: r.lg ?? 16,
    },
    summaryRow: { flexDirection: 'row', justifyContent: 'space-between' },
    primaryButton: {
      minHeight: 52,
      borderRadius: r.md ?? 12,
      backgroundColor: c.accent ?? '#E8B33C',
      alignItems: 'center',
      justifyContent: 'center',
    },
    primaryLabel: { color: c.onAccent ?? '#0B0E14', fontWeight: '700', fontSize: theme.fontSize.callout ?? 17 },
    disabled: { opacity: 0.4 },
  });
}
