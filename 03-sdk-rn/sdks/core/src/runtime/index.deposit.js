import { AppRegistry } from 'react-native';
import { DepositScreen } from '../../../deposit/src/DepositScreen';

/** Runtime + deposit surface only (no bet slip). */
import './RuntimeRegistry';

function withMountLog(name, Component) {
  return function FeatureWrapper(props) {
    return <Component {...props} />;
  };
}

AppRegistry.registerComponent('DepositFeature', () => withMountLog('DepositFeature', DepositScreen));

AppRegistry.registerComponent('FightDeckRuntimeBootstrap', () => {
  const React = require('react');
  const { Text, View } = require('react-native');
  return function Bootstrap() {
    return (
      <View style={{ flex: 1, backgroundColor: '#0B0E14' }}>
        <Text style={{ color: '#9AA5B8' }}>FightDeck RN runtime</Text>
      </View>
    );
  };
});
