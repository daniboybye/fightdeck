import type { ViewProps } from 'react-native';
import codegenNativeComponent from 'react-native/Libraries/Utilities/codegenNativeComponent';

export interface NativeProps extends ViewProps {
  label: string;
  accent?: boolean;
}

/** Fabric component — native side wraps SwiftUI (iOS) / Compose (Android). */
export default codegenNativeComponent<NativeProps>('FightDeckNativeBadge');
