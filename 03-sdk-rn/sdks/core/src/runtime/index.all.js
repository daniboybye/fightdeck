import { AppRegistry } from 'react-native';
import { DepositScreen } from '../../../deposit/src/DepositScreen';
import { BetslipScreen } from '../../../betslip/src/BetslipScreen';
import { FighterScreen } from '../../../fighter/src/FighterScreen';

/** Shared runtime entry — registers all SDK feature surfaces in one bundle. */
import './RuntimeRegistry';

function withMountLog(name, Component) {
  return function FeatureWrapper(props) {
    if (__DEV__) {
      console.log(`[FightDeckRN] surface mounted: ${name}`);
    }
    return <Component {...props} />;
  };
}

AppRegistry.registerComponent('DepositFeature', () => withMountLog('DepositFeature', DepositScreen));
AppRegistry.registerComponent('BetslipFeature', () => withMountLog('BetslipFeature', BetslipScreen));
AppRegistry.registerComponent('FighterFeature', () => withMountLog('FighterFeature', FighterScreen));

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
