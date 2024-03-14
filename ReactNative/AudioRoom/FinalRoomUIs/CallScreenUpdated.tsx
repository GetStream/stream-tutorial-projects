import {
  useStreamVideoClient,
} from '@stream-io/video-react-native-sdk';

import { Call } from '@stream-io/video-react-native-sdk';
type Props = { goToHomeScreen: () => void; callId: string };

export const CallScreen = ({goToHomeScreen, callId}: Props) => {

  const [callState, setCallState] = React.useState<Call | null>(null);
  const client = useStreamVideoClient();

  const call = client?.call('audio_room', callId);
    useEffect(() => {
      // After this step the call is live and you can start sending and receiving audio.
      const [call, setCall] = React.useState<Call | null>(null);

      if (call) {
        call
          .join({
            create: true,
            data: {
              members: [{user_id: 'john_smith'}, {user_id: 'jane_doe'}],
              custom: {
                title: 'React Native test',
                description: 'We are doing a test of react native audio rooms',
              },
            },
          })
          .then(() => call.goLive())
          .then(() => setCall(call));
      }
  }, [client]);
};
