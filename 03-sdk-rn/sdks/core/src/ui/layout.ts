/** Mirrors native `DesignTokens.Layout` — HIG tap target and primary action height. */
import { Platform, PlatformColor, type ColorValue } from 'react-native';
import type { ThemeTokens } from './theme';

export const MIN_TAP_TARGET = 44;
export const PRIMARY_ACTION_HEIGHT = 44;
export const SUCCESS_BUTTON_HEIGHT = 44;
export const SECONDARY_ACTION_PADDING = 24;
export const ACTION_BAR_GAP = 12;
/** The host's floating tab bar sits higher than the bottom edge of the surface. */
export const TAB_BAR_ACTION_GAP = 20;
const ACTION_BAR_PADDING_TOP = 8;

/**
 * The host sizes the surface to the space its chrome and the keyboard leave, so the only
 * thing the scroll content has to clear is the pinned bar itself.
 */
export const ACTION_BAR_SCROLL_INSET =
  ACTION_BAR_GAP + ACTION_BAR_PADDING_TOP + PRIMARY_ACTION_HEIGHT + ACTION_BAR_GAP;

/**
 * What a grouped list sits on. iOS lists sample the system's grouped background rather than
 * a token, so the surface asks UIKit for the same colour instead of being told it.
 */
export function pageBackground(theme: ThemeTokens): ColorValue {
  return Platform.OS === 'ios'
    ? PlatformColor('systemGroupedBackground')
    : theme.colors.background ?? '#0B0E14';
}
