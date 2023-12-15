import React from 'react';
import { StreamCall, StreamVideo, StreamVideoClient, User } from '@stream-io/video-react-native-sdk';
import { SafeAreaView, Text, StyleSheet, View, Image } from 'react-native';

const apiKey = 'hd8szvscpxvd'; // the API key can be found in the "Credentials" section
const token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiTWFyYV9KYWRlIiwiaXNzIjoiaHR0cHM6Ly9wcm9udG8uZ2V0c3RyZWFtLmlvIiwic3ViIjoidXNlci9NYXJhX0phZGUiLCJpYXQiOjE3MDI0NTQwMDQsImV4cCI6MTcwMzA1ODgwOX0.ERKM-3w-YqiubkxY_3SGvLQs85RUshJcKN-AkiJc8hg'; // the token can be found in the "Credentials" section
const userId = 'Mara_Jade'; // the user id can be found in the "Credentials" section
const callId = 'qovA6tXL837X'; // the call id can be found in the "Credentials" section

// Initialize the user object. The user can be anonymous, guest, or authenticated
const user: User = {
  id: userId,
  name: 'Santhosh',
  image: `https://getstream.io/random_png/?id=${userId}&name=Santhosh`,
};

// Initialize the client by passing the API Key, user and user token. Your backend typically generates the user and token on sign-up or login.
const myClient = new StreamVideoClient({ apiKey, user, token });

/*
How to create a call. Stream uses the same call object for livestreaming, audio rooms and video calling. 
To create the first call object, specify the call type as livestream and provide a unique callId. 
The livestream call type comes with default settings that are usually suitable for live streams, 
but you can customize features, permissions, and settings in the dashboard. 
Additionally, the dashboard allows you to create new call types as required.
*/
const myCall = myClient.call('livestream', callId);

// Finally, using call.join({ create: true }) will not only create the call object on our servers but also initiate the real-time transport for audio and video. 
myCall.join({ create: true });

export default function App() {
  return (
    <StreamVideo client={myClient} language='en'>
      <StreamCall call={myCall}>
        <SafeAreaView style={{ flex: 1 }}>
          <LivestreamUI />
        </SafeAreaView>
      </StreamCall>
    </StreamVideo>
  );
}

const styles = StyleSheet.create({
  center: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding : 20,
  },
  text: {
    fontSize: 30, 
    color: '#005fff', 
    textAlign: 'center',
    marginTop: 64, // Add this line to increase the vertical space
  },
});

const LivestreamUI = () => (
  <View style={styles.center}>
    <Image source={require('./src/todo.png')} style={{ width: 424, height: 235 }} />
    <Text style={styles.text}>✅ TODO: How To Render a Live Video</Text>
  </View>
);
