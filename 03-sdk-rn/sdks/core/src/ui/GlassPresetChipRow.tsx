import React from 'react';
import {
  Platform,
  Pressable,
  requireNativeComponent,
  StyleSheet,
  Text,
  View,
  type NativeSyntheticEvent,
  type StyleProp,
  type ViewStyle,
} from 'react-native';
import { MIN_TAP_TARGET } from './layout';
import type { ThemeTokens } from './theme';

interface NativeSelectEvent {
  value: string;
}

interface NativeGlassChipRowProps {
  values: string[];
  accentHex: string;
  style?: StyleProp<ViewStyle>;
  onSelect?: (event: NativeSyntheticEvent<NativeSelectEvent>) => void;
}

const NativeGlassChipRow =
  Platform.OS === 'ios'
    ? requireNativeComponent<NativeGlassChipRowProps>('FightDeckGlassChipRowView')
    : null;

interface GlassPresetChipRowProps {
  theme: ThemeTokens;
  values: number[];
  onSelect: (value: number) => void;
  style?: StyleProp<ViewStyle>;
}

export function GlassPresetChipRow({ theme, values, onSelect, style }: GlassPresetChipRowProps) {
  const c = theme.colors;
  const s = theme.spacing;
  const r = theme.radius;
  const labels = values.map((value) => `€${value}`);
  const accentHex = c.accent ?? '#E8B33C';

  if (NativeGlassChipRow != null) {
    return (
      <NativeGlassChipRow
        style={[styles.nativeRow, { height: MIN_TAP_TARGET }, style]}
        values={labels}
        accentHex={accentHex}
        onSelect={(event) => {
          const raw = event.nativeEvent.value.replace('€', '');
          const parsed = Number.parseInt(raw, 10);
          if (!Number.isNaN(parsed)) {
            onSelect(parsed);
          }
        }}
      />
    );
  }

  return (
    <View style={[styles.fallbackRow, { gap: s.sm ?? 8 }, style]}>
      {values.map((chip) => (
        <Pressable
          key={chip}
          accessibilityRole="button"
          accessibilityLabel={`€${chip}`}
          style={({ pressed }) => [
            styles.fallbackChip,
            {
              borderRadius: r.full ?? 999,
              borderColor: c.border ?? '#232A38',
              backgroundColor: c.surfaceElevated ?? '#1C2230',
            },
            pressed && styles.pressed,
          ]}
          onPress={() => onSelect(chip)}
        >
          <Text style={[styles.fallbackLabel, { color: accentHex }]}>€{chip}</Text>
        </Pressable>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  nativeRow: {
    width: '100%',
    backgroundColor: 'transparent',
  },
  fallbackRow: {
    flexDirection: 'row',
  },
  fallbackChip: {
    flex: 1,
    height: MIN_TAP_TARGET,
    borderWidth: StyleSheet.hairlineWidth,
    alignItems: 'center',
    justifyContent: 'center',
  },
  fallbackLabel: {
    fontWeight: '600',
  },
  pressed: {
    opacity: 0.85,
  },
});
