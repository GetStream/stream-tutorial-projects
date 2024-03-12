import React, { useState } from 'react';
import { SafeAreaView, StyleSheet } from 'react-native';
import { HomeScreen } from './src/HomeScreen';
import { CallScreen } from './src/CallScreen';

const apiKey = 'mmhfdzb5evj2'; // the API key can be found in the "Credentials" section
const token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiTHVtaW5hcmFfVW5kdWxpIiwiaXNzIjoiaHR0cHM6Ly9wcm9udG8uZ2V0c3RyZWFtLmlvIiwic3ViIjoidXNlci9MdW1pbmFyYV9VbmR1bGkiLCJpYXQiOjE3MTAxNTIxOTgsImV4cCI6MTcxMDc1NzAwM30.smXS4RxGRN_4YfDdVBp_H5WEqRE9D8dup_hTCYLW-xs'; // the token can be found in the "Credentials" section
const userId = 'Luminara_Unduli'; // the user id can be found in the "Credentials" section
const callId = 'jAyJsH08BJoX'; // the call id can be found in the "Credentials" section

export default function App() {
  const [activeScreen, setActiveScreen] = useState('home');
  const goToCallScreen = () => setActiveScreen('call-screen');
  const goToHomeScreen = () => setActiveScreen('home');

  return (
    <SafeAreaView style={styles.container}>
      {activeScreen === 'call-screen' ? (
        <CallScreen goToHomeScreen={goToHomeScreen} callId={callId} />
      ) : (
        <HomeScreen goToCallScreen={goToCallScreen} />
      )}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    textAlign: 'center',
  },
});
