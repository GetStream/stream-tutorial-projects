import { useCall, useCallStateHooks } from '@stream-io/video-react-native-sdk';
import React from 'react';
import { Button } from 'react-native';

export const ToggleLiveButton = () => {
  // this utility hook returns the call object from the <StreamCall /> context
  const call = useCall();
  // will emit a new value whenever the call goes live or stops being live.
  // we can use it to update the button text or adjust any other UI elements
  const { useIsCallLive } = useCallStateHooks();
  const isLive = useIsCallLive();
  return (
    <Button
      title={`${isLive ? 'Stop' : 'Go'} Live`}
      onPress={() => {
        if (isLive) {
          call?.stopLive();
        } else {
          call?.goLive();
        }
      }}
    />
  );
};
