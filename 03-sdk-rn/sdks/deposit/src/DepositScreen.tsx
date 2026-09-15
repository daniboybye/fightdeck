import React, { useEffect, useMemo, useState } from 'react';
import {
  BackHandler,
  Keyboard,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { notifyNative } from '../../core/src/runtime/RuntimeRegistry';
import { formatCurrency, money, parseMoney } from '../../core/src/fightcore/money';
import { PinnedActionBar } from '../../core/src/ui/PinnedActionBar';
import {
  MIN_TAP_TARGET,
  SECONDARY_ACTION_PADDING,
  SUCCESS_BUTTON_HEIGHT,
  actionBarScrollInset,
  useSurfaceLayout,
} from '../../core/src/ui/layout';
import { GlassPresetChipRow } from '../../core/src/ui/GlassPresetChipRow';
import { parseThemeJSON } from '../../core/src/ui/theme';
import { TestIds } from '../../core/src/ui/testIds';

const MIN_DEPOSIT = parseMoney('10.00');
const MAX_DEPOSIT = parseMoney('2000.00');

const METHODS = [
  { id: 'card', title: 'Card', fee: 'Instant · 0% fee', rate: 0 },
  { id: 'bank', title: 'Bank transfer', fee: '1–2 days · 0% fee', rate: 0 },
  { id: 'wallet', title: 'Wallet', fee: 'Instant · 1% fee', rate: 0.01 },
];

export function DepositScreen(props: Record<string, unknown>) {
  return <DepositScreenContent {...props} />;
}

function DepositScreenContent(props: Record<string, unknown>) {
  const layoutFrame = useSurfaceLayout(props, 'DepositFeature');

  const theme = useMemo(
    () => parseThemeJSON(String(props.themeJSON ?? '{}')),
    [props.themeJSON],
  );
  const balance = parseMoney(String(props.currentBalance ?? '0'));
  const [amountText, setAmountText] = useState('');
  const [methodId, setMethodId] = useState('card');
  const [didSucceed, setDidSucceed] = useState(false);
  const [amountFocused, setAmountFocused] = useState(false);

  const styles = useMemo(
    () => makeStyles(theme, layoutFrame.chromeBackground),
    [theme, layoutFrame.chromeBackground],
  );
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
      <View style={[styles.root, styles.successRoot]} testID="deposit-success">
        <View style={[styles.successContent, { paddingTop: layoutFrame.safeAreaTop }]}>
          <Text style={styles.successIcon}>✓</Text>
          <Text style={styles.title}>Deposit successful</Text>
          <Text style={styles.secondary}>
            New balance: {formatCurrency(money(balance.plus(amount)))}
          </Text>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Done"
            style={({ pressed }) => [styles.doneButton, pressed && styles.pressed]}
            onPress={done}
          >
            <Text style={styles.primaryLabel}>Done</Text>
          </Pressable>
        </View>
      </View>
    );
  }

  const scrollInset = actionBarScrollInset(
    layoutFrame.safeAreaBottom,
    layoutFrame.keyboardBottomInset,
  );
  const confirmDisabled = amountError != null || amountText.length === 0;

  return (
    // No `accessible` on this container: it would collapse the whole screen into a single
    // accessibility element and hide the amount field, the presets and the action bar from
    // VoiceOver — and from anything else driving the app through the accessibility tree.
    <View style={styles.root} testID={TestIds.depositReady}>
      <ScrollView
        style={styles.flex}
        contentContainerStyle={[
          styles.content,
          { paddingTop: layoutFrame.safeAreaTop + (theme.spacing.lg ?? 16), paddingBottom: scrollInset },
        ]}
        // The host hands the surface the area under the navigation bar and tells us how deep
        // it is; letting UIKit guess as well would inset the content twice.
        contentInsetAdjustmentBehavior="never"
        keyboardShouldPersistTaps="handled"
        keyboardDismissMode={Platform.OS === 'ios' ? 'interactive' : 'on-drag'}
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
          style={styles.amountInput}
          testID="deposit-amount"
          // No returnKeyType: a decimal pad has no return key, so React Native answers one
          // by hanging its own Done toolbar off the keyboard — which lands on top of the
          // action bar. Done lives in the bar instead.
          keyboardType="decimal-pad"
          placeholder="€10 – €2,000"
          placeholderTextColor={theme.colors.textSecondary}
          value={amountText}
          onPressIn={() => setAmountFocused(true)}
          onFocus={() => setAmountFocused(true)}
          onBlur={() => setAmountFocused(false)}
          onChangeText={setAmountText}
        />
        {amountError ? <Text style={styles.error}>{amountError}</Text> : null}
        <View style={styles.chipRow}>
          <GlassPresetChipRow
            theme={theme}
            values={[10, 25, 50, 100]}
            onSelect={(chip) => setAmountText(String(chip))}
          />
        </View>

        <Text style={styles.sectionTitle}>Method</Text>
        {METHODS.map((item) => (
          <Pressable
            key={item.id}
            style={({ pressed }) => [
              styles.methodRow,
              methodId === item.id && styles.methodSelected,
              pressed && styles.pressed,
            ]}
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
      </ScrollView>
      <PinnedActionBar
        theme={theme}
        primaryTitle="Confirm deposit"
        safeAreaBottom={layoutFrame.safeAreaBottom}
        keyboardBottomInset={layoutFrame.keyboardBottomInset}
        primaryDisabled={confirmDisabled}
        showDone={amountFocused || layoutFrame.textInputActive || layoutFrame.keyboardBottomInset > 0}
        onDonePress={dismissKeyboard}
        onPrimaryPress={confirmDeposit}
      />
    </View>
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

function makeStyles(theme: ReturnType<typeof parseThemeJSON>, chromeBackground: string) {
  const c = theme.colors;
  const s = theme.spacing;
  const r = theme.radius;
  const pageBackground = chromeBackground || c.background || '#0B0E14';
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: pageBackground },
    successRoot: { flex: 1 },
    flex: { flex: 1 },
    content: { paddingHorizontal: s.lg ?? 16, paddingBottom: s.lg ?? 16, gap: s.lg ?? 16 },
    // Sentence case, not caps: this is what a SwiftUI `Section("Amount")` header looks like.
    sectionTitle: {
      color: c.textSecondary ?? '#9AA5B8',
      fontSize: theme.fontSize.callout ?? 17,
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
      flex: 1,
      height: MIN_TAP_TARGET,
      borderRadius: r.full ?? 999,
      backgroundColor: c.surfaceElevated ?? '#1C2230',
      alignItems: 'center',
      justifyContent: 'center',
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
    doneButton: {
      height: SUCCESS_BUTTON_HEIGHT,
      paddingHorizontal: SECONDARY_ACTION_PADDING,
      borderRadius: SUCCESS_BUTTON_HEIGHT / 2,
      backgroundColor: c.accent ?? '#E8B33C',
      alignItems: 'center',
      justifyContent: 'center',
    },
    primaryLabel: { color: c.onAccent ?? '#0B0E14', fontWeight: '700', fontSize: theme.fontSize.callout ?? 17 },
    pressed: { opacity: 0.85 },
  });
}
