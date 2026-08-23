import React, { useMemo, useState } from 'react';
import {
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
import {
  FightCore,
  MIN_ACCA_LEGS,
  boutIndexFromDataset,
} from '../../core/src/fightcore/fightcore';
import { formatCurrency, formatMoney, parseMoney } from '../../core/src/fightcore/money';
import { formatOdds, parseOdds } from '../../core/src/fightcore/odds';
import { notifyNative } from '../../core/src/runtime/RuntimeRegistry';
import { parseThemeJSON, slipSummaryRows } from '../../core/src/ui/theme';
import { TestIds } from '../../core/src/ui/testIds';
import type { BetMode, Selection } from '../../core/src/fightcore/types';

interface SlipProps extends Record<string, unknown> {
  themeJSON: string;
  balance: string;
  slipJSON: string;
  eventsJSON: string;
}

interface SelectionLabels {
  fighterName: string;
  opponentName: string;
  eventName: string;
}

const STAKE_INPUT_ID = 'betslipStakeInput';

function modeFor(count: number): BetMode {
  return count >= MIN_ACCA_LEGS ? 'accumulator' : 'single';
}

function selectionLabels(eventsJSON: string, selection: Selection): SelectionLabels {
  const events = JSON.parse(eventsJSON || '{"events":[]}').events ?? [];
  for (const event of events) {
    for (const bout of event.bouts ?? []) {
      if (bout.id !== selection.boutId) {
        continue;
      }
      const red = bout.redCorner;
      const blue = bout.blueCorner;
      const picked = red.fighterId === selection.fighterId ? red : blue;
      const opponent = picked === red ? blue : red;
      return {
        fighterName: picked.name ?? selection.fighterId,
        opponentName: opponent.name ?? '—',
        eventName: event.name ?? '—',
      };
    }
  }
  return {
    fighterName: selection.fighterId,
    opponentName: '—',
    eventName: '—',
  };
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

export function BetslipScreen(props: SlipProps) {
  const theme = useMemo(() => parseThemeJSON(String(props.themeJSON ?? '{}')), [props.themeJSON]);
  const styles = makeStyles(theme);
  const eventsJSON = String(props.eventsJSON ?? '{"events":[]}');
  const core = useMemo(() => {
    const events = JSON.parse(eventsJSON);
    return new FightCore(boutIndexFromDataset(events.events ?? []));
  }, [eventsJSON]);

  const initial = JSON.parse(String(props.slipJSON ?? '{}')) as {
    stake?: string;
    selections?: Array<{ boutId: string; fighterId: string; odds: string }>;
  };

  const [stakeText, setStakeText] = useState(initial.stake ?? '10.00');
  const [selections, setSelections] = useState<Selection[]>(
    (initial.selections ?? []).map((s) => ({
      boutId: s.boutId,
      fighterId: s.fighterId,
      odds: parseOdds(s.odds),
    })),
  );
  const [placedMessage, setPlacedMessage] = useState<string | null>(null);

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
    notifyNative('betslip', {
      type: 'updated',
      slipJSON: slipPayload(nextSelections, nextStake),
    });
  };

  const dismissKeyboard = () => Keyboard.dismiss();

  if (selections.length === 0) {
    return (
      <SafeAreaView style={[styles.root, styles.emptyRoot]} testID={TestIds.betslipEmpty}>
        <Text style={styles.secondary}>No selections yet</Text>
        <Pressable
          style={styles.primaryButton}
          accessibilityRole="button"
          accessibilityLabel="Browse Events"
          onPress={() => notifyNative('betslip', { type: 'browse' })}
        >
          <Text style={styles.primaryLabel}>Browse Events</Text>
        </Pressable>
      </SafeAreaView>
    );
  }

  const betTypeTitle = slipMode === 'accumulator' ? 'Accumulator' : 'Single';

  return (
    <SafeAreaView style={styles.root}>
      <TouchableWithoutFeedback onPress={dismissKeyboard} accessible={false}>
        <ScrollView
          style={styles.flex}
          contentContainerStyle={styles.content}
          keyboardShouldPersistTaps="handled"
        >
          <Text style={styles.sectionTitle}>{betTypeTitle}</Text>
          {selections.map((selection) => {
            const labels = selectionLabels(eventsJSON, selection);
            return (
              <View key={`${selection.boutId}-${selection.fighterId}`} style={styles.row}>
                <View style={styles.flex}>
                  <Text style={styles.body}>{labels.fighterName}</Text>
                  <Text style={styles.secondary}>
                    vs {labels.opponentName} · {labels.eventName}
                  </Text>
                </View>
                <Text style={styles.accent}>{formatOdds(selection.odds)}</Text>
                <Pressable
                  onPress={() => {
                    const next = selections.filter(
                      (s) => !(s.boutId === selection.boutId && s.fighterId === selection.fighterId),
                    );
                    setSelections(next);
                    setPlacedMessage(null);
                    notifyUpdated(next, stakeText);
                  }}
                >
                  <Text style={styles.secondary}> ✕ </Text>
                </Pressable>
              </View>
            );
          })}

          <Text style={styles.sectionTitle}>Stake</Text>
          <TextInput
            nativeID={STAKE_INPUT_ID}
            inputAccessoryViewID={Platform.OS === 'ios' ? STAKE_INPUT_ID : undefined}
            style={styles.stakeInput}
            keyboardType="decimal-pad"
            returnKeyType="done"
            blurOnSubmit
            onSubmitEditing={dismissKeyboard}
            value={stakeText}
            onChangeText={(text) => {
              setStakeText(text);
              notifyUpdated(selections, text);
            }}
          />
          <View style={styles.chipRow}>
            {[5, 10, 25, 50].map((chip) => (
              <Pressable
                key={chip}
                style={styles.chip}
                onPress={() => {
                  const next = String(chip);
                  setStakeText(next);
                  notifyUpdated(selections, next);
                }}
              >
                <Text style={styles.chipLabel}>€{chip}</Text>
              </Pressable>
            ))}
          </View>
          <View style={styles.summary}>
            {summary.map((row) => (
              <View key={row.label} style={styles.summaryRow}>
                <Text style={styles.secondary}>{row.label}</Text>
                <Text style={styles.body}>{row.value}</Text>
              </View>
            ))}
          </View>
          {state.errors.map((error) => (
            <Text key={error} style={styles.error}>{error.replaceAll('_', ' ')}</Text>
          ))}
          <View style={styles.depositCard}>
            <Text style={styles.depositTitle}>Deposit</Text>
            <View style={styles.summaryRow}>
              <Text style={styles.secondary}>Balance</Text>
              <Text style={styles.body}>{formatCurrency(balance)}</Text>
            </View>
            <Pressable
              testID={TestIds.betslipAddFunds}
              accessibilityRole="button"
              accessibilityLabel="Add funds"
              style={styles.primaryButton}
              onPress={() => notifyNative('betslip', { type: 'deposit' })}
            >
              <Text style={styles.primaryLabel}>Add funds</Text>
            </Pressable>
          </View>
          {placedMessage ? (
            <Text style={styles.positive}>{placedMessage}</Text>
          ) : null}
          <Pressable
            style={[styles.primaryButton, state.errors.length > 0 && styles.disabled]}
            disabled={state.errors.length > 0}
            onPress={() => {
              if (state.errors.length > 0) {
                return;
              }
              const message = `Bet placed · ${formatCurrency(state.potentialReturn)} to return`;
              const nextBalance = formatMoney(balance.minus(state.totalStake));
              const clearedStake = stakeText;
              setPlacedMessage(message);
              setSelections([]);
              notifyNative('betslip', {
                type: 'placed',
                message,
                slipJSON: slipPayload([], clearedStake),
                balance: nextBalance,
              });
            }}
          >
            <Text style={styles.primaryLabel}>Place bet</Text>
          </Pressable>
        </ScrollView>
      </TouchableWithoutFeedback>
      {Platform.OS === 'ios' ? (
        <InputAccessoryView nativeID={STAKE_INPUT_ID}>
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

function makeStyles(theme: ReturnType<typeof parseThemeJSON>) {
  const c = theme.colors;
  const s = theme.spacing;
  const r = theme.radius;
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: c.background ?? '#0B0E14' },
    flex: { flex: 1 },
    emptyRoot: {
      justifyContent: 'center',
      alignItems: 'center',
      gap: s.lg ?? 16,
      padding: s.xl ?? 24,
    },
    content: { padding: s.lg ?? 16, gap: s.md ?? 12, paddingBottom: s.xl ?? 24 },
    sectionTitle: {
      color: c.textSecondary ?? '#9AA5B8',
      fontSize: theme.fontSize.caption ?? 12,
      fontWeight: '600',
      textTransform: 'uppercase',
    },
    body: { color: c.textPrimary ?? '#F5F7FA', fontSize: theme.fontSize.body ?? 15 },
    secondary: { color: c.textSecondary ?? '#9AA5B8', fontSize: theme.fontSize.caption ?? 12 },
    accent: { color: c.accent ?? '#E8B33C', fontWeight: '600' },
    positive: { color: c.positive ?? '#3DD68C', fontWeight: '600' },
    error: { color: c.negative ?? '#F2545B' },
    row: {
      flexDirection: 'row',
      alignItems: 'center',
      gap: s.md ?? 12,
      padding: s.lg ?? 16,
      backgroundColor: c.surface ?? '#141922',
      borderRadius: r.lg ?? 16,
    },
    stakeInput: {
      color: c.textPrimary ?? '#F5F7FA',
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
    summary: {
      gap: s.sm ?? 8,
      padding: s.lg ?? 16,
      backgroundColor: c.surfaceElevated ?? '#1C2230',
      borderRadius: r.lg ?? 16,
    },
    summaryRow: { flexDirection: 'row', justifyContent: 'space-between' },
    depositCard: {
      gap: s.sm ?? 8,
      padding: s.lg ?? 16,
      backgroundColor: c.surface ?? '#141922',
      borderRadius: r.lg ?? 16,
    },
    depositTitle: {
      color: c.textPrimary ?? '#F5F7FA',
      fontSize: theme.fontSize.callout ?? 17,
      fontWeight: '600',
    },
    primaryButton: {
      minHeight: 52,
      borderRadius: r.md ?? 12,
      backgroundColor: c.accent ?? '#E8B33C',
      alignItems: 'center',
      justifyContent: 'center',
    },
    primaryLabel: { color: c.onAccent ?? '#0B0E14', fontWeight: '700' },
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
