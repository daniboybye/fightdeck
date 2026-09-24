/**
 * Everything that crosses between a host and a React surface, other than the surface's own
 * properties, declared once.
 *
 * Codegen turns this file into the ObjC++ protocol and JSI glue on iOS and the Java base class
 * and JNI glue on Android. A method added here and forgotten on either side is caught by the
 * compiler — an error on Android, where the base class declares it abstract, and a
 * missing-protocol-method warning on iOS — where the untyped `postResult(feature, payload)` it
 * replaces accepted any dictionary and left each host to re-parse it with a string switch.
 */
import type { CodegenTypes, TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

/** The host chrome a surface has to clear, in the density-independent units styles use. */
export type SurfaceLayout = {
  moduleName: string;
  safeAreaTop: CodegenTypes.Double;
  safeAreaBottom: CodegenTypes.Double;
  keyboardBottomInset: CodegenTypes.Double;
  chromeBackground: string;
  textInputActive: boolean;
};

export interface Spec extends TurboModule {
  depositConfirmed(): void;
  /** A plain decimal, no currency sign: the host parses it straight into its money type. */
  depositCompleted(amount: string): void;

  betslipUpdated(slipJSON: string): void;
  betslipBrowseEvents(): void;
  betslipDeposit(): void;
  betslipPlaced(message: string, slipJSON: string, balance: string): void;

  /** The last layout the host published for this surface, read once when it mounts. */
  surfaceLayout(moduleName: string): SurfaceLayout | null;
  /**
   * Every layout after that. Chrome does not travel as a property because a property update
   * re-renders the surface from its root, and keyboard frames change precisely because a field
   * gained focus.
   */
  readonly onSurfaceLayout: CodegenTypes.EventEmitter<SurfaceLayout>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('FightDeckRuntimeBridge');
