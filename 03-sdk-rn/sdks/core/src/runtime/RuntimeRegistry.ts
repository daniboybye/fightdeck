import { NativeEventEmitter, NativeModules } from 'react-native';

type FeatureHandler = (payload: Record<string, unknown>) => void;

const registry = new Map<string, FeatureHandler>();

/** Native posts results here — zero modules registered in the host app. */
export const runtimeEvents = new NativeEventEmitter(
  NativeModules.FightDeckRuntimeBridge ?? undefined,
);

runtimeEvents.addListener('fightdeckFeatureResult', (event: object) => {
  const { feature, payload } = event as {
    feature: string;
    payload: Record<string, unknown>;
  };
  registry.get(feature)?.(payload);
});

export function registerFeature(
  name: string,
  handler: FeatureHandler,
): void {
  registry.set(name, handler);
}

export function unregisterFeature(name: string): void {
  registry.delete(name);
}

export function notifyNative(feature: string, payload: Record<string, unknown>): void {
  NativeModules.FightDeckRuntimeBridge?.postResult(feature, payload);
}
