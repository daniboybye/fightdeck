import React, { useEffect, useMemo, useState } from 'react';
import {
  BackHandler,
  InputAccessoryView,
  Keyboard,
  Platform,
  Pressable,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableWithoutFeedback,
  View,
} from 'react-native';
import { notifyNative } from '../../core/src/runtime/RuntimeRegistry';
import { formatCurrency, money, parseMoney } from '../../core/src/fightcore/money';
import { parseThemeJSON } from '../../core/src/ui/theme';
import { TestIds } from '../../core/src/ui/testIds';

const MIN_DEPOSIT = parseMoney('10.00');
const MAX_DEPOSIT = parseMoney('2000.00');
const AMOUNT_INPUT_ID = 'depositAmountInput';

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

  useEffect(() => {
    if (!didSucceed) {
      return undefined;
    }
    notifyNative('deposit', { type: 'confirmed' });
    const subscription = BackHandler.addEventListener('hardwareBackPress', () => true);
    return () => subscription.remove();
  }, [didSucceed]);

  const confirmDeposit = () => {
    setDidSucceed(true);
  };

  const done = () => {
    notifyNative('deposit', { type: 'completed', amount: formatCurrency(amount) });
  };

  const dismissKeyboard = () => Keyboard.dismiss();

  if (didSucceed) {
    return (
      <SafeAreaView style={styles.root} testID="deposit-success">
        <View style={styles.successContent}>
          <Text style={styles.successIcon}>✓</Text>
          <Text style={styles.title}>Deposit successful</Text>
          <Text style={styles.secondary}>
            New balance: {formatCurrency(money(balance.plus(amount)))}
          </Text>
          <Pressable style={styles.primaryButton} onPress={done}>
            <Text style={styles.primaryLabel}>Done</Text>
          </Pressable>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView
      style={styles.root}
      testID={TestIds.depositReady}
      accessible
      accessibilityLabel="Deposit"
    >
      <TouchableWithoutFeedback onPress={dismissKeyboard} accessible={false}>
        <ScrollView
          style={styles.flex}
          contentContainerStyle={styles.content}
          keyboardShouldPersistTaps="handled"
        >
          <Text style={styles.sectionTitle}>Amount</Text>
          <Text
            testID={TestIds.depositBalance}
            accessibilityLabel="Balance"
            style={styles.secondary}
          >
            Balance: {formatCurrency(balance)}
          </Text>
          <TextInput
            nativeID={AMOUNT_INPUT_ID}
            inputAccessoryViewID={Platform.OS === 'ios' ? AMOUNT_INPUT_ID : undefined}
            style={styles.amountInput}
            keyboardType="decimal-pad"
            returnKeyType="done"
            blurOnSubmit
            onSubmitEditing={dismissKeyboard}
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

          <Text style={styles.sectionTitle}>Method</Text>
          {METHODS.map((item) => (
            <Pressable
              key={item.id}
              style={[styles.methodRow, methodId === item.id && styles.methodSelected]}
              onPress={() => setMethodId(item.id)}
            >
              <Text style={styles.methodRadio}>{methodId === item.id ? '◉' : '○'}</Text>
              <View style={styles.flex}>
                <Text style={styles.body}>{item.title}</Text>
                <Text style={styles.secondary}>{item.fee}</Text>
              </View>
            </Pressable>
          ))}

          <Text style={styles.sectionTitle}>Summary</Text>
          <View style={styles.summary}>
            <SummaryRow label="Amount" value={formatCurrency(amount)} styles={styles} />
            <SummaryRow label="Method" value={method.title} styles={styles} />
            <SummaryRow label="Fee" value={formatCurrency(fee)} styles={styles} />
            <SummaryRow label="Total" value={formatCurrency(total)} styles={styles} />
            <SummaryRow
              label="New balance"
              value={formatCurrency(money(balance.plus(amount)))}
              styles={styles}
            />
          </View>

          <Pressable
            style={[
              styles.primaryButton,
              (amountError != null || amountText.length === 0) && styles.disabled,
            ]}
            disabled={amountError != null || amountText.length === 0}
            onPress={confirmDeposit}
          >
            <Text style={styles.primaryLabel}>Confirm deposit</Text>
          </Pressable>
        </ScrollView>
      </TouchableWithoutFeedback>
      {Platform.OS === 'ios' ? (
        <InputAccessoryView nativeID={AMOUNT_INPUT_ID}>
          <View style={styles.accessoryBar}>
            <Pressable onPress={dismissKeyboard} hitSlop={8}>
              <Text style={styles.accessoryDone}>Done</Text>
            </Pressable>
          </View>
        </InputAccessoryView>
      ) : null}
    </SafeAreaView>
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
    flex: { flex: 1 },
    content: { padding: s.lg ?? 16, gap: s.lg ?? 16, paddingBottom: s.xl ?? 24 },
    sectionTitle: {
      color: c.textSecondary ?? '#9AA5B8',
      fontSize: theme.fontSize.caption ?? 12,
      fontWeight: '600',
      textTransform: 'uppercase',
    },
    title: { color: c.textPrimary ?? '#F5F7FA', fontSize: theme.fontSize.title ?? 22, fontWeight: '700' },
    body: { color: c.textPrimary ?? '#F5F7FA', fontSize: theme.fontSize.body ?? 15 },
    secondary: { color: c.textSecondary ?? '#9AA5B8', fontSize: theme.fontSize.body ?? 15 },
    error: { color: c.negative ?? '#F2545B', fontSize: theme.fontSize.caption ?? 12 },
    successContent: {
      flex: 1,
      justifyContent: 'center',
      alignItems: 'center',
      gap: s.lg ?? 16,
      padding: s.xl ?? 24,
    },
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
    accessoryBar: {
      flexDirection: 'row',
      justifyContent: 'flex-end',
      paddingHorizontal: s.lg ?? 16,
      paddingVertical: s.sm ?? 8,
      backgroundColor: c.surfaceElevated ?? '#1C2230',
      borderTopWidth: StyleSheet.hairlineWidth,
      borderTopColor: c.border ?? '#232A38',
    },
    accessoryDone: {
      color: c.accent ?? '#E8B33C',
      fontWeight: '600',
      fontSize: theme.fontSize.callout ?? 17,
    },
  });
}
