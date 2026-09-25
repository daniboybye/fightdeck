import React from 'react';
import {
  Pressable,
  StyleSheet,
  Text,
  View,
  type StyleProp,
  type ViewStyle,
} from 'react-native';
import { ACTION_BAR_GAP, PRIMARY_ACTION_HEIGHT } from './layout';
import type { ThemeTokens } from './theme';

interface PinnedActionBarProps {
  theme: ThemeTokens;
  primaryTitle: string;
  onPrimaryPress: () => void;
  primaryDisabled?: boolean;
  showDone?: boolean;
  onDonePress?: () => void;
  /// What the bar rests on when no field is being edited. The host's floating tab bar needs
  /// a wider gap than the home indicator does; the keyboard, which Done dismisses, does not.
  restingGap?: number;
  style?: StyleProp<ViewStyle>;
}

export function PinnedActionBar({
  theme,
  primaryTitle,
  onPrimaryPress,
  primaryDisabled = false,
  showDone = false,
  onDonePress,
  restingGap = ACTION_BAR_GAP,
  style,
}: PinnedActionBarProps) {
  const styles = makeStyles(theme);
  const gap = showDone ? ACTION_BAR_GAP : restingGap;

  return (
    <View
      style={[
        styles.bar,
        { paddingBottom: gap },
        style,
      ]}
      pointerEvents="box-none"
    >
      <View style={styles.row}>
        <Pressable
          style={({ pressed }) => [
            styles.primaryButton,
            primaryDisabled && styles.disabled,
            pressed && !primaryDisabled && styles.pressed,
          ]}
          disabled={primaryDisabled}
          accessibilityRole="button"
          accessibilityLabel={primaryTitle}
          onPress={onPrimaryPress}
        >
          <Text style={[styles.primaryLabel, primaryDisabled && styles.disabledLabel]}>
            {primaryTitle}
          </Text>
        </Pressable>
        {showDone ? (
          <Pressable
            testID="Done"
            style={({ pressed }) => [styles.doneButton, pressed && styles.pressed]}
            accessibilityRole="button"
            accessibilityLabel="Done"
            onPress={onDonePress}
          >
            <Text style={styles.doneLabel}>Done</Text>
          </Pressable>
        ) : null}
      </View>
    </View>
  );
}

function makeStyles(theme: ThemeTokens) {
  const c = theme.colors;
  const s = theme.spacing;
  return StyleSheet.create({
    bar: {
      position: 'absolute',
      left: 0,
      right: 0,
      bottom: 0,
      // No fill behind the buttons. The host's SwiftUI bar is a pair of glass pills floating
      // over the scrolled content, and an opaque strip is further from that than nothing is:
      // React Native has no blur of its own to reach for here.
      paddingHorizontal: s.lg ?? 16,
      paddingTop: s.sm ?? 8,
    },
    row: {
      flexDirection: 'row',
      alignItems: 'center',
      gap: s.sm ?? 8,
    },
    primaryButton: {
      flex: 1,
      height: PRIMARY_ACTION_HEIGHT,
      borderRadius: PRIMARY_ACTION_HEIGHT / 2,
      backgroundColor: c.accent ?? '#E8B33C',
      alignItems: 'center',
      justifyContent: 'center',
    },
    primaryLabel: {
      color: c.onAccent ?? '#0B0E14',
      fontWeight: '700',
      fontSize: theme.fontSize.callout ?? 17,
    },
    doneButton: {
      // Matches the primary button beside it. A shorter pill in the same row reads as a
      // misalignment rather than a hierarchy.
      height: PRIMARY_ACTION_HEIGHT,
      borderRadius: PRIMARY_ACTION_HEIGHT / 2,
      borderWidth: StyleSheet.hairlineWidth,
      borderColor: c.border ?? '#232A38',
      backgroundColor: 'rgba(56, 64, 82, 0.92)',
      paddingHorizontal: s.lg ?? 16,
      alignItems: 'center',
      justifyContent: 'center',
    },
    doneLabel: {
      color: c.accent ?? '#E8B33C',
      fontWeight: '600',
      fontSize: theme.fontSize.callout ?? 17,
    },
    // Dimming the whole button would make it translucent, and the scrolled content behind the
    // bar would read straight through the fill. Swap the colours instead.
    disabled: { backgroundColor: c.surfaceElevated ?? '#1C2230' },
    disabledLabel: { color: c.textSecondary ?? '#8A93A6' },
    pressed: { opacity: 0.85 },
  });
}
