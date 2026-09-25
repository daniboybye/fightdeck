/**
 * The grouped-list chrome — card fill, hairline and section-header colour — taken from the
 * platform instead of from the FightDeck palette.
 *
 * On iOS the hand-written screens never choose these. `List` in its inset-grouped style asks
 * UIKit, which is why a native card is a neutral `secondarySystemGroupedBackground` while the
 * palette's `surface` is a blue-tinted `#141922`. Put the two screens side by side and the
 * React Native one reads as a different app, even though every number and every string on it
 * is right. React Native has an API for exactly this problem: `PlatformColor` resolves a
 * semantic `UIColor` by name at render time, so the component tree stays one implementation
 * and the colour comes from the OS.
 *
 * Android deliberately stays on the palette. `00-native` paints its Compose cards from
 * FightDeck's own tokens rather than from Material's defaults, so resolving these against the
 * platform there would move *away* from the native counterpart, not towards it.
 */
import { Platform, PlatformColor, type ColorValue } from 'react-native';
import type { ThemeTokens } from './theme';

export interface GroupedChrome {
  card: ColorValue;
  separator: ColorValue;
  sectionHeader: ColorValue;
}

export function groupedChrome(theme: ThemeTokens): GroupedChrome {
  const c = theme.colors;
  const palette: GroupedChrome = {
    card: c.surface ?? '#141922',
    separator: c.border ?? '#232A38',
    sectionHeader: c.textSecondary ?? '#9AA5B8',
  };
  if (Platform.OS !== 'ios') {
    return palette;
  }
  return {
    card: PlatformColor('secondarySystemGroupedBackground'),
    separator: PlatformColor('separator'),
    sectionHeader: PlatformColor('secondaryLabel'),
  };
}
