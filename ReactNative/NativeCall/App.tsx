import React, {useState} from 'react';
import {SafeAreaView, StyleSheet} from 'react-native';
import {HomeScreen} from './src/HomeScreen';
import {CallScreen} from './src/CallScreen';

// 1. Import the StreamVideo and StreamVideoClient components
import {
  StreamVideo,
  StreamVideoClient,
} from '@stream-io/video-react-native-sdk';

// 2. Create a StreamVideoClient instance
const apiKey = 'mmhfdzb5evj2'; // the API key can be found in the "Credentials" section
const token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiSUdfODgiLCJpc3MiOiJodHRwczovL3Byb250by5nZXRzdHJlYW0uaW8iLCJzdWIiOiJ1c2VyL0lHXzg4IiwiaWF0IjoxNzAyMzU1MzY2LCJleHAiOjE3MDI5NjAxNzF9.mxQjXlMT8vqfMHE6CUwHFhn2KnlTJo6iisI0hKuIEzI'; // the token can be found in the "Credentials" section
const userId = 'IG_88'; // the user id can be found in the "Credentials" section
const callId = '1LQuK5pZWBHM'; // the call id can be found in the "Credentials" section

// 3. Create a user object
const user = {
  id: userId,
  name: 'John Malkovich',
  image: `https://getstream.io/random_png/?id=${userId}&name=John+Malkovich`,
};
// 4. Create a StreamVideoClient instance
const client = new StreamVideoClient({ apiKey, user, token });

export default function App() {
  const [activeScreen, setActiveScreen] = useState('home');
  const goToCallScreen = () => setActiveScreen('call-screen');
  const goToHomeScreen = () => setActiveScreen('home');

  return (
    // 5. Wrap your app with the StreamVideo component
    <StreamVideo client={client}>
      <SafeAreaView style={styles.container}>
        {activeScreen === 'call-screen' ? (
          <CallScreen goToHomeScreen={goToHomeScreen} callId={callId} />
        ) : (
          <HomeScreen goToCallScreen={goToCallScreen} />
        )}
      </SafeAreaView>
    </StreamVideo>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    textAlign: 'center',
  },
});
