//import React from 'react';
import React, {useEffect} from 'react';
import {Button, StyleSheet, Text, View} from 'react-native';

import {Call, StreamCall, useStreamVideoClient, CallContent} from '@stream-io/video-react-native-sdk';

type Props = {goToHomeScreen: () => void; callId: string};

export const CallScreen = ({goToHomeScreen, callId}: Props) => {
    const [call, setCall] = React.useState<Call | null>(null);
    const client = useStreamVideoClient();

    useEffect(() => {
        if (client) {
            const call = client.call('default', callId);
            call.join({ create: true })
                .then(() => setCall(call));
        }
    }, [client]);

    if (!call) {
        return (
            <View style={joinStyles.container}>
                <Text style={styles.text}>Joining call...</Text>
            </View>
        );
    }

    return (
    <StreamCall call={call}>
    <View style={styles.container}>
        <CallContent
            onHangupCallHandler={goToHomeScreen}
        />
    </View>
    </StreamCall>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
  },
  text: {
    fontSize: 20,
    fontWeight: 'bold',
    marginBottom: 20,
    textAlign: 'center',
    color: '#005fff',
  },
});

const joinStyles = StyleSheet.create({
    container: {
      flex: 1,
      justifyContent: 'center',
      alignItems: 'center',
    },
    text: {
      padding: 20,
      // Additional styles for the text if needed
    },
  });
