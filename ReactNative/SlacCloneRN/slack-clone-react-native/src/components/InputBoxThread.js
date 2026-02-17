/**
 * InputBoxThread - Legacy component
 *
 * This component is no longer used directly. In stream-chat-react-native v8,
 * the Thread component handles its own input rendering internally.
 *
 * Kept for reference purposes.
 */
import React from 'react';
import {View, StyleSheet} from 'react-native';
import {useTheme} from '@react-navigation/native';

export const InputBoxThread = ({children}) => {
  const {colors} = useTheme();

  return (
    <View style={[styles.container, {backgroundColor: colors.background}]}>
      {children}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flexDirection: 'column',
    width: '100%',
  },
});
