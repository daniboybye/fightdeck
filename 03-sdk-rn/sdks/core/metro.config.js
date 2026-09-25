const path = require('path');
const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');

const projectRoot = __dirname;
const monorepoRoot = path.resolve(projectRoot, '..');

const config = {
  projectRoot,
  watchFolders: [
    path.resolve(monorepoRoot, 'deposit'),
    path.resolve(monorepoRoot, 'betslip'),
    path.resolve(monorepoRoot, 'fighter'),
    // The design tokens, which the theme imports rather than receiving from the host.
    path.resolve(monorepoRoot, '../../shared-ui-spec'),
  ],
  resolver: {
    nodeModulesPaths: [
      path.resolve(projectRoot, 'node_modules'),
      path.resolve(monorepoRoot, '../node_modules'),
    ],
  },
};

module.exports = mergeConfig(getDefaultConfig(projectRoot), config);
