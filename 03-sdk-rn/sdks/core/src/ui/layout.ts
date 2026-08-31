/** Mirrors native `DesignTokens.Layout` — HIG tap target and primary action height. */
import { useEffect, useState } from 'react';
import { NativeEventEmitter, NativeModules } from 'react-native';

export const MIN_TAP_TARGET = 44;
export const PRIMARY_ACTION_HEIGHT = 44;
export const SUCCESS_BUTTON_HEIGHT = 44;
export const SECONDARY_ACTION_PADDING = 24;
export const ACTION_BAR_GAP = 12;
/** The host's floating tab bar sits higher than the safe area it reports. */
export const TAB_BAR_ACTION_GAP = 20;
const ACTION_BAR_PADDING_TOP = 8;

export interface SurfaceLayoutProps {
  moduleName?: unknown;
  safeAreaTop?: unknown;
  safeAreaBottom?: unknown;
  keyboardBottomInset?: unknown;
  chromeBackground?: unknown;
  textInputActive?: unknown;
  layoutStamp?: unknown;
}

export function readSurfaceLayout(props: SurfaceLayoutProps) {
  return {
    safeAreaTop: Math.max(0, Number(props.safeAreaTop ?? 0)),
    // No upper clamp: the Android host reports 168px of tab-bar clearance, and capping below
    // that put the pinned action bar underneath the tab bar.
    safeAreaBottom: Math.max(0, Number(props.safeAreaBottom ?? 0)),
    keyboardBottomInset: Math.min(400, Math.max(0, Number(props.keyboardBottomInset ?? 0))),
    chromeBackground: String(props.chromeBackground ?? '').trim(),
    textInputActive: Boolean(props.textInputActive),
  };
}

const layoutEvents = NativeModules.FightDeckRuntimeBridge != null
  ? new NativeEventEmitter(NativeModules.FightDeckRuntimeBridge)
  : null;

/** Host props plus native layout events — props alone miss keyboard frames on Fabric surfaces. */
export function useSurfaceLayout(props: SurfaceLayoutProps, moduleName: string) {
  const [frame, setFrame] = useState(() => readSurfaceLayout(props));

  useEffect(() => {
    setFrame(readSurfaceLayout(props));
  }, [
    props.safeAreaTop,
    props.safeAreaBottom,
    props.keyboardBottomInset,
    props.chromeBackground,
    props.textInputActive,
    props.layoutStamp,
  ]);

  useEffect(() => {
    if (layoutEvents == null) {
      return undefined;
    }
    const subscription = layoutEvents.addListener(
      'fightdeckSurfaceLayout',
      (event: object) => {
        const payload = event as SurfaceLayoutProps;
        if (String(payload.moduleName ?? '') !== moduleName) {
          return;
        }
        setFrame(readSurfaceLayout(payload));
      },
    );
    return () => subscription.remove();
  }, [moduleName]);

  return frame;
}

/** Host passes bottom chrome; keyboard lift replaces (not stacks on) tab-bar clearance. */
export function actionBarScrollInset(safeAreaBottom = 0, keyboardBottomInset = 0): number {
  const chrome = Math.max(Math.max(0, safeAreaBottom), Math.max(0, keyboardBottomInset));
  return chrome + ACTION_BAR_GAP + ACTION_BAR_PADDING_TOP + PRIMARY_ACTION_HEIGHT + ACTION_BAR_GAP;
}
