import React from 'react';
import { Button, StyleSheet, Text, View } from 'react-native';
import {AudioRoomControlsPanel} from './AudioRoomControlsPanel';
import {AudioRoomDescription} from './AudioRoomDescription';
import {AudioRoomParticipants} from './AudioRoomParticipants';

type Props = { goToHomeScreen: () => void };

export const AudioRoomUI = ({ goToHomeScreen }: Props) => {
    return (
        <View style={styles.container}>
            <AudioRoomDescription />
            <AudioRoomParticipants />
            <AudioRoomControlsPanel />
            <Button title='Leave Audio Room' onPress={goToHomeScreen} />
        </View>
    );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 4,
    justifyContent: 'center',
  },
  text: {
    fontSize: 20,
    fontWeight: 'bold',
    marginBottom: 20,
    textAlign: 'center',
  },
});
