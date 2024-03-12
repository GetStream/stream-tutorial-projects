import React from 'react';

import { AudioRoomUI } from './AudioRoomUI';

type Props = { goToHomeScreen: () => void; callId: string };

export const CallScreen = ({ goToHomeScreen, callId }: Props) => {
  return <AudioRoomUI goToHomeScreen={goToHomeScreen} />;
};
