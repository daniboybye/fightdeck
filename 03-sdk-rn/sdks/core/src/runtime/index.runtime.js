import { AppRegistry } from 'react-native';

/** Runtime-only bundle — Hermes host bootstrap, no feature surfaces. */
import './RuntimeRegistry';

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
