import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

export interface Spec extends TurboModule {
  read(key: string): Promise<string | null>;
  write(key: string, value: string): Promise<void>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('PreferencesStore');
