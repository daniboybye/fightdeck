import { AppRegistry } from 'react-native';
import { DepositScreen } from '../../../deposit/src/DepositScreen';
import { feature } from './feature';

/** Runtime + deposit surface only (no bet slip). */

AppRegistry.registerComponent('DepositFeature', feature(DepositScreen));
