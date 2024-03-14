import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import {ToggleLiveButton} from './ToggleLiveButton';
import {ToggleMicButton} from './ToggleMicButton';

export const AudioRoomControlsPanel = () => {
  return (
    <View style={styles.container}>
       <ToggleLiveButton />
       <ToggleMicButton />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    padding: 4,
    flexDirection: 'row',
    justifyContent: 'center',
  },
});
