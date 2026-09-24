import { AppRegistry } from 'react-native';
import { DepositScreen } from '../../../deposit/src/DepositScreen';
import { BetslipScreen } from '../../../betslip/src/BetslipScreen';
import { feature } from './feature';

/** Shared runtime entry — registers all SDK feature surfaces in one bundle. */

AppRegistry.registerComponent('DepositFeature', feature(DepositScreen));
AppRegistry.registerComponent('BetslipFeature', feature(BetslipScreen));

AppRegistry.registerComponent('FightDeckRuntimeBootstrap', () => {
  const React = require('react');
  const { Text, View } = require('react-native');
  return function Bootstrap() {
    if (__DEV__) {
      console.log('[FightDeckRN] runtime bootstrap mounted');
    }
    return (
      <View style={{ flex: 1, backgroundColor: '#0B0E14' }}>
        <Text style={{ color: '#9AA5B8' }}>FightDeck RN runtime</Text>
      </View>
    );
  };
});
