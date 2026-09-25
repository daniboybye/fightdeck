import React, { useEffect, useMemo, useRef, useState } from 'react';
import {
  Keyboard,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
  type StyleProp,
  type ViewStyle,
} from 'react-native';
import { FightCore, MIN_ACCA_LEGS } from '../../core/src/fightcore/fightcore';
import { formatCurrency, formatMoney, parseMoney } from '../../core/src/fightcore/money';
import { formatOdds, parseOdds } from '../../core/src/fightcore/odds';
import Runtime from '../../core/src/specs/NativeFightDeckRuntimeBridge';
import { PinnedActionBar } from '../../core/src/ui/PinnedActionBar';
import {
  MIN_TAP_TARGET,
  SECONDARY_ACTION_PADDING,
  SUCCESS_BUTTON_HEIGHT,
  TAB_BAR_ACTION_GAP,
  ACTION_BAR_SCROLL_INSET,
  pageBackground,
} from '../../core/src/ui/layout';
import { GlassPresetChipRow } from '../../core/src/ui/GlassPresetChipRow';
import { slipSummaryRows, theme, type ThemeTokens } from '../../core/src/ui/theme';
import { TestIds } from '../../core/src/ui/testIds';
import type { BetMode, BoutIndex, Selection } from '../../core/src/fightcore/types';

interface SlipProps extends Record<string, unknown> {
  balance: string;
  slipJSON: string;
  betPlacedMessage?: unknown;
}

/**
 * One leg as the host sends it: the pick, and enough of its bout to name it and to check it
 * against. The host builds every selection from its own catalogue, so a copy of that catalogue
 * here could only ever confirm what the host already knows.
 */
interface SlipLeg {
  boutId: string;
  fighterId: string;
  opponentId: string;
  odds: string;
  fighterName: string;
  opponentName: string;
  eventName: string;
}

interface HostSlip {
  stake?: string;
  selections?: SlipLeg[];
}

function modeFor(count: number): BetMode {
  return count >= MIN_ACCA_LEGS ? 'accumulator' : 'single';
}

function slipPayload(selections: Selection[], stakeText: string): string {
  return JSON.stringify({
    mode: modeFor(selections.length),
    stake: stakeText,
    selections: selections.map((s) => ({
      boutId: s.boutId,
      fighterId: s.fighterId,
      odds: formatMoney(s.odds),
    })),
  });
}

function parseSelections(raw: SlipLeg[] | undefined): Selection[] {
  return (raw ?? []).map((s) => ({
    boutId: s.boutId,
    fighterId: s.fighterId,
    odds: parseOdds(s.odds),
  }));
}

export function BetslipScreen(props: SlipProps) {
  const styles = useMemo(() => makeStyles(theme), []);
  const slipJSONProp = String(props.slipJSON ?? '{}');
  const legs = useMemo(
    () => new Map(((JSON.parse(slipJSONProp) as HostSlip).selections ?? []).map((leg) => [leg.boutId, leg])),
    [slipJSONProp],
  );
  const core = useMemo(
    () => new FightCore([...legs.values()].map((leg): BoutIndex => ({
      id: leg.boutId,
      redFighterId: leg.fighterId,
      blueFighterId: leg.opponentId,
      winnerId: '',
    }))),
    [legs],
  );

  const initial = JSON.parse(slipJSONProp) as HostSlip;

  const [stakeText, setStakeText] = useState(initial.stake ?? '10.00');
  const [selections, setSelections] = useState<Selection[]>(parseSelections(initial.selections));
  // Owned by the host, so the confirmation outlives a new presentation of the surface, which
  // starts the React tree afresh.
  const placedMessage = String(props.betPlacedMessage ?? '') || null;
  const [stakeFocused, setStakeFocused] = useState(false);
  const stakeFocusedRef = useRef(false);
  const stakeInputRef = useRef<React.ComponentRef<typeof TextInput>>(null);

  useEffect(() => {
    const parsed = JSON.parse(slipJSONProp) as HostSlip;
    setSelections(parseSelections(parsed.selections));
    if (!stakeFocusedRef.current) {
      setStakeText(parsed.stake ?? '10.00');
    }
  }, [slipJSONProp]);

  const balance = parseMoney(String(props.balance ?? '0'));
  const slipMode = modeFor(selections.length);
  const slip = { mode: slipMode, selections, stake: parseMoney(stakeText || '0') };
  const state = core.slipState(slip, balance);

  const summary = slipSummaryRows({
    combinedOddsDisplay: state.combinedOddsDisplay ? formatMoney(state.combinedOddsDisplay) : null,
    totalStake: formatCurrency(state.totalStake),
    potentialReturn: formatCurrency(state.potentialReturn),
    potentialProfit: formatCurrency(state.potentialProfit),
  });

  const notifyUpdated = (nextSelections: Selection[], nextStake: string) => {
    Runtime.betslipUpdated(slipPayload(nextSelections, nextStake));
  };

  const dismissKeyboard = () => Keyboard.dismiss();

  if (selections.length === 0 && placedMessage) {
    return (
      <View
        style={[styles.root, styles.emptyRoot]}
        testID="betslip-placed"
      >
        <Text style={styles.positive}>Bet placed</Text>
        <Text style={styles.body}>{placedMessage}</Text>
        <Pressable
          style={({ pressed }) => [styles.successButton, pressed && styles.pressed]}
          accessibilityRole="button"
          accessibilityLabel="Browse Events"
          onPress={() => Runtime.betslipBrowseEvents()}
        >
          <Text style={styles.primaryLabel}>Browse Events</Text>
        </Pressable>
      </View>
    );
  }

  if (selections.length === 0) {
    return (
      <View
        style={[styles.root, styles.emptyRoot]}
        testID={TestIds.betslipEmpty}
      >
        <Text style={styles.secondary}>No selections yet</Text>
        <Pressable
          style={({ pressed }) => [styles.successButton, pressed && styles.pressed]}
          accessibilityRole="button"
          accessibilityLabel="Browse Events"
          onPress={() => Runtime.betslipBrowseEvents()}
        >
          <Text style={styles.primaryLabel}>Browse Events</Text>
        </Pressable>
      </View>
    );
  }

  const betTypeTitle = slipMode === 'accumulator' ? 'Accumulator' : 'Single';

  return (
    <View style={styles.root}>
      <ScrollView
        style={styles.flex}
        contentContainerStyle={[
          styles.content,
          { paddingTop: theme.spacing.sm ?? 8, paddingBottom: ACTION_BAR_SCROLL_INSET },
        ]}
        // The host hands the surface the area under the navigation bar and tells us how deep
        // it is; letting UIKit guess as well would inset the content twice.
        contentInsetAdjustmentBehavior="never"
        keyboardShouldPersistTaps="handled"
        keyboardDismissMode={Platform.OS === 'ios' ? 'interactive' : 'on-drag'}
      >
        <GroupedSection title={betTypeTitle} theme={theme}>
          {selections.map((selection, index) => {
            const leg = legs.get(selection.boutId);
            const isLast = index === selections.length - 1;
            return (
              <GroupedRow key={`${selection.boutId}-${selection.fighterId}`} theme={theme} isLast={isLast}>
                <View style={styles.selectionMain}>
                  <View style={styles.flex}>
                    <Text style={styles.body}>{leg?.fighterName ?? selection.fighterId}</Text>
                    <Text style={styles.secondary}>
                      vs {leg?.opponentName ?? '—'} · {leg?.eventName ?? '—'}
                    </Text>
                  </View>
                  <Text style={styles.accent}>{formatOdds(selection.odds)}</Text>
                  <Pressable
                    hitSlop={8}
                    accessibilityRole="button"
                    accessibilityLabel="Remove selection"
                    onPress={() => {
                      const next = selections.filter(
                        (s) => !(s.boutId === selection.boutId && s.fighterId === selection.fighterId),
                      );
                      setSelections(next);
                      notifyUpdated(next, stakeText);
                    }}
                  >
                    <Text style={styles.removeLabel}>✕</Text>
                  </Pressable>
                </View>
              </GroupedRow>
            );
          })}
        </GroupedSection>

        <GroupedSection title="Stake" theme={theme} overflowVisible>
          <GroupedRow theme={theme} compact>
            <Pressable style={styles.labeledRow} onPress={() => stakeInputRef.current?.focus()}>
              <Text style={styles.body}>Amount</Text>
              <TextInput
                ref={stakeInputRef}
                style={styles.stakeInput}
                testID="betslip-stake-amount"
                keyboardType="decimal-pad"
                value={stakeFocused ? stakeText : formatCurrency(parseMoney(stakeText || '0'))}
                onFocus={() => {
                  stakeFocusedRef.current = true;
                  setStakeFocused(true);
                }}
                onBlur={() => {
                  stakeFocusedRef.current = false;
                  setStakeFocused(false);
                }}
                onChangeText={(text) => {
                  setStakeText(text);
                  notifyUpdated(selections, text);
                }}
              />
            </Pressable>
          </GroupedRow>
          <View style={styles.chipRow}>
            <GlassPresetChipRow
              theme={theme}
              values={[5, 10, 25, 50]}
              onSelect={(chip) => {
                const next = String(chip);
                setStakeText(next);
                notifyUpdated(selections, next);
              }}
            />
          </View>
        </GroupedSection>

        <GroupedSection theme={theme}>
          {summary.map((row, index) => (
            <GroupedRow key={row.label} theme={theme} isLast={index === summary.length - 1}>
              <View style={styles.summaryRow}>
                <Text style={styles.body}>{row.label}</Text>
                <Text style={styles.secondary}>{row.value}</Text>
              </View>
            </GroupedRow>
          ))}
        </GroupedSection>

        {state.errors.length > 0 ? (
          <GroupedSection theme={theme}>
            {state.errors.map((error, index) => (
              <GroupedRow key={error} theme={theme} isLast={index === state.errors.length - 1}>
                <Text style={styles.error}>{error.replaceAll('_', ' ')}</Text>
              </GroupedRow>
            ))}
          </GroupedSection>
        ) : null}

        <GroupedSection title="Deposit" theme={theme}>
          <GroupedRow theme={theme}>
            <View style={styles.summaryRow}>
              <Text style={styles.body}>Balance</Text>
              <Text style={styles.body}>{formatCurrency(balance)}</Text>
            </View>
          </GroupedRow>
          <GroupedRow theme={theme} isLast>
            <Pressable
              testID={TestIds.betslipAddFunds}
              accessibilityRole="button"
              accessibilityLabel="Add funds"
              style={({ pressed }) => [styles.linkButton, pressed && styles.pressed]}
              onPress={() => Runtime.betslipDeposit()}
            >
              <Text style={styles.linkLabel}>Add funds</Text>
            </Pressable>
          </GroupedRow>
        </GroupedSection>
      </ScrollView>
      <PinnedActionBar
        theme={theme}
        primaryTitle="Place bet"
        primaryDisabled={state.errors.length > 0}
        restingGap={TAB_BAR_ACTION_GAP}
        showDone={stakeFocused}
        onDonePress={dismissKeyboard}
        onPrimaryPress={() => {
          if (state.errors.length > 0) {
            return;
          }
          const message = `${formatCurrency(state.potentialReturn)} returns if it lands`;
          const nextBalance = formatMoney(balance.minus(state.totalStake));
          const clearedStake = stakeText;
          setSelections([]);
          Runtime.betslipPlaced(message, slipPayload([], clearedStake), nextBalance);
        }}
      />
    </View>
  );
}

function GroupedSection({
  title,
  theme,
  children,
  style,
  overflowVisible = false,
}: {
  title?: string;
  theme: ThemeTokens;
  children: React.ReactNode;
  style?: StyleProp<ViewStyle>;
  overflowVisible?: boolean;
}) {
  const c = theme.colors;
  const s = theme.spacing;
  return (
    <View style={[{ marginBottom: s.lg ?? 16 }, style]}>
      {title ? <Text style={groupedStyles(c, theme).header}>{title}</Text> : null}
      <View style={[groupedStyles(c, theme, overflowVisible).group]}>{children}</View>
    </View>
  );
}

function GroupedRow({
  theme,
  children,
  isLast = false,
  compact = false,
}: {
  theme: ThemeTokens;
  children: React.ReactNode;
  isLast?: boolean;
  /// For rows whose own content already stands 44pt tall, such as a text field.
  compact?: boolean;
}) {
  const c = theme.colors;
  const s = theme.spacing;
  return (
    <View>
      <View
        style={{
          paddingHorizontal: s.lg ?? 16,
          paddingVertical: compact ? 0 : s.md ?? 12,
        }}
      >
        {children}
      </View>
      {!isLast ? <View style={[groupedStyles(c, theme).divider, { marginLeft: s.lg ?? 16 }]} /> : null}
    </View>
  );
}

function groupedStyles(c: Record<string, string>, theme: ThemeTokens, overflowVisible = false) {
  const s = theme.spacing;
  const r = theme.radius;
  return StyleSheet.create({
    header: {
      color: c.textSecondary ?? '#9AA5B8',
      fontSize: theme.fontSize.callout ?? 17,
      marginBottom: s.sm ?? 8,
      marginHorizontal: s.lg ?? 16,
    },
    group: {
      backgroundColor: c.surface ?? '#141922',
      borderRadius: r.lg ?? 16,
      overflow: overflowVisible ? 'visible' : 'hidden',
    },
    divider: {
      height: StyleSheet.hairlineWidth,
      backgroundColor: c.border ?? '#232A38',
    },
  });
}

function makeStyles(theme: ThemeTokens) {
  const c = theme.colors;
  const s = theme.spacing;
  const r = theme.radius;
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: pageBackground(theme) },
    flex: { flex: 1 },
    emptyRoot: {
      flex: 1,
      justifyContent: 'center',
      alignItems: 'center',
      gap: s.lg ?? 16,
      padding: s.xl ?? 24,
    },
    content: { paddingHorizontal: s.lg ?? 16 },
    body: { color: c.textPrimary ?? '#F5F7FA', fontSize: theme.fontSize.body ?? 15 },
    secondary: { color: c.textSecondary ?? '#9AA5B8', fontSize: theme.fontSize.caption ?? 12 },
    accent: {
      color: c.accent ?? '#E8B33C',
      fontWeight: '600',
      fontSize: theme.fontSize.callout ?? 17,
    },
    positive: { color: c.positive ?? '#3DD68C', fontWeight: '600', fontSize: theme.fontSize.title ?? 22 },
    error: { color: c.negative ?? '#F2545B', fontSize: theme.fontSize.callout ?? 17 },
    selectionMain: {
      flexDirection: 'row',
      alignItems: 'flex-start',
      gap: s.md ?? 12,
    },
    labeledRow: {
      flexDirection: 'row',
      alignItems: 'center',
      justifyContent: 'space-between',
      minHeight: MIN_TAP_TARGET,
      gap: s.md ?? 12,
    },
    // Full row height, not the height of one line of text: an 18pt strip is under the tap
    // target and a thumb aiming at it lands on the row instead and nothing happens.
    stakeInput: {
      flex: 1,
      height: MIN_TAP_TARGET,
      color: c.textPrimary ?? '#F5F7FA',
      fontSize: theme.fontSize.body ?? 15,
      textAlign: 'right',
      paddingVertical: 0,
    },
    chipRow: {
      paddingHorizontal: s.lg ?? 16,
      paddingTop: s.md ?? 12,
      paddingBottom: s.md ?? 12,
    },
    chip: {
      flex: 1,
      height: MIN_TAP_TARGET,
      borderRadius: r.full ?? 999,
      borderWidth: StyleSheet.hairlineWidth,
      borderColor: c.border ?? '#232A38',
      backgroundColor: c.surfaceElevated ?? '#1C2230',
      alignItems: 'center',
      justifyContent: 'center',
    },
    chipLabel: { color: c.accent ?? '#E8B33C', fontWeight: '600' },
    summaryRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
    linkButton: {
      height: MIN_TAP_TARGET,
      justifyContent: 'center',
      // Stretch, so the row responds to a tap anywhere on it and not only on the label.
      alignSelf: 'stretch',
    },
    linkLabel: {
      color: c.accent ?? '#E8B33C',
      fontSize: theme.fontSize.body ?? 15,
    },
    removeLabel: {
      color: c.textSecondary ?? '#9AA5B8',
      fontSize: theme.fontSize.callout ?? 17,
      paddingHorizontal: s.xs ?? 4,
    },
    successButton: {
      height: SUCCESS_BUTTON_HEIGHT,
      paddingHorizontal: SECONDARY_ACTION_PADDING,
      borderRadius: SUCCESS_BUTTON_HEIGHT / 2,
      backgroundColor: c.accent ?? '#E8B33C',
      alignItems: 'center',
      justifyContent: 'center',
    },
    primaryLabel: {
      color: c.onAccent ?? '#0B0E14',
      fontWeight: '700',
      fontSize: theme.fontSize.callout ?? 17,
    },
    pressed: { opacity: 0.85 },
  });
}
