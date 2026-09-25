import { AppRegistry } from 'react-native';
import { DepositScreen } from '../../../deposit/src/DepositScreen';
import { BetslipScreen } from '../../../betslip/src/BetslipScreen';
import { FighterScreen } from '../../../fighter/src/FighterScreen';
import { feature } from './feature';

/** Shared runtime entry — registers all SDK feature surfaces in one bundle. */

AppRegistry.registerComponent('DepositFeature', feature(DepositScreen));
AppRegistry.registerComponent('BetslipFeature', feature(BetslipScreen));
AppRegistry.registerComponent('FighterFeature', feature(FighterScreen));
