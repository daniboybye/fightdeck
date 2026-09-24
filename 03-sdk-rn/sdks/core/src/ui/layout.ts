/** Mirrors native `DesignTokens.Layout` — HIG tap target and primary action height. */
import { useEffect, useState } from 'react';
import Runtime, { type SurfaceLayout } from '../specs/NativeFightDeckRuntimeBridge';

export const MIN_TAP_TARGET = 44;
export const PRIMARY_ACTION_HEIGHT = 44;
export const SUCCESS_BUTTON_HEIGHT = 44;
export const SECONDARY_ACTION_PADDING = 24;
export const ACTION_BAR_GAP = 12;
/** The host's floating tab bar sits higher than the safe area it reports. */
export const TAB_BAR_ACTION_GAP = 20;
const ACTION_BAR_PADDING_TOP = 8;

function readSurfaceLayout(layout: SurfaceLayout | null) {
  return {
    safeAreaTop: Math.max(0, layout?.safeAreaTop ?? 0),
    // No upper clamp: hosts report chrome in the same density-independent units these styles
    // use, and the Android tab bar is deeper than anything worth hard-coding here.
    safeAreaBottom: Math.max(0, layout?.safeAreaBottom ?? 0),
    keyboardBottomInset: Math.min(400, Math.max(0, layout?.keyboardBottomInset ?? 0)),
    chromeBackground: layout?.chromeBackground.trim() ?? '',
    textInputActive: layout?.textInputActive ?? false,
  };
}

/** The chrome the host last published for this surface, then every change to it. */
export function useSurfaceLayout(moduleName: string) {
  const [frame, setFrame] = useState(() => readSurfaceLayout(Runtime.surfaceLayout(moduleName)));

  useEffect(() => {
    const subscription = Runtime.onSurfaceLayout((layout) => {
      if (layout.moduleName === moduleName) {
        setFrame(readSurfaceLayout(layout));
      }
    });
    // Read again now that the listener is in place: a layout published between the first
    // render and this effect would otherwise be the one the surface never sees.
    setFrame(readSurfaceLayout(Runtime.surfaceLayout(moduleName)));
    return () => subscription.remove();
  }, [moduleName]);

  return frame;
}

/** Host passes bottom chrome; keyboard lift replaces (not stacks on) tab-bar clearance. */
export function actionBarScrollInset(safeAreaBottom = 0, keyboardBottomInset = 0): number {
  const chrome = Math.max(Math.max(0, safeAreaBottom), Math.max(0, keyboardBottomInset));
  return chrome + ACTION_BAR_GAP + ACTION_BAR_PADDING_TOP + PRIMARY_ACTION_HEIGHT + ACTION_BAR_GAP;
}
