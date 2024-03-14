import React, { useEffect } from 'react';
import { Text, View, StyleSheet } from 'react-native';

import {
  Call, StreamCall,
  useStreamVideoClient,
} from '@stream-io/video-react-native-sdk';
import { AudioRoomUI } from './AudioRoomUI';

type Props = { goToHomeScreen: () => void; callId: string };

export const CallScreen = ({goToHomeScreen, callId}: Props) => {
  const [call, setCall] = React.useState<Call | null>(null);
  const client = useStreamVideoClient();
  
  const styles = StyleSheet.create({
        container: {
            // add your styles here
        },
});

  if (!call) {
    return <Text>Joining call...</Text>;
  }

  return (
    <StreamCall call={call}>
      <View style={styles.container}>
        <AudioRoomUI goToHomeScreen={goToHomeScreen} />
      </View>
    </StreamCall>
  );
};
