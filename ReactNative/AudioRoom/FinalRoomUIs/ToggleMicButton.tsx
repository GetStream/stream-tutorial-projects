import { useCall, useCallStateHooks, useIncallManager } from '@stream-io/video-react-native-sdk';
import React from 'react';
import { Button } from 'react-native';

export const ToggleMicButton = () => {
  useIncallManager({media: 'video', auto: true});
  const call = useCall();
  const { useMicrophoneState } = useCallStateHooks();
  const { status } = useMicrophoneState();

  const onPress = () => {
    call?.microphone.toggle();
  };

  return <Button title={`${status === 'enabled' ? 'Mute' : 'Unmute'}`} onPress={onPress} />;
};
