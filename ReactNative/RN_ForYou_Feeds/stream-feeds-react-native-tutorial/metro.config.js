const { getDefaultConfig } = require('expo/metro-config');

const config = getDefaultConfig(__dirname);

// Enable package exports support for @stream-io packages
config.resolver.unstable_enablePackageExports = true;

module.exports = config;
