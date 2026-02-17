const {getDefaultConfig, mergeConfig} = require('@react-native/metro-config');

const defaultConfig = getDefaultConfig(__dirname);
const {assetExts, sourceExts} = defaultConfig.resolver;

/**
 * Metro configuration
 * https://reactnative.dev/docs/metro
 *
 * @type {import('metro-config').MetroConfig}
 */
const config = {
  transformer: {
    babelTransformerPath: require.resolve('react-native-svg-transformer'),
  },
  resolver: {
    assetExts: assetExts.filter(ext => ext !== 'svg'),
    sourceExts: [...sourceExts, 'svg'],
    // Enable package.json "exports" field support so that packages like
    // axios resolve their "react-native" condition instead of the Node.js build
    unstable_enablePackageExports: true,
    unstable_conditionNames: ['react-native', 'browser', 'require', 'import'],
  },
};

module.exports = mergeConfig(defaultConfig, config);
