import type {
  User,
  ChannelSort,
  ChannelFilters,
  ChannelOptions,
} from 'stream-chat';
import {
  useCreateChatClient,
  Chat,
  Channel,
  ChannelHeader,
  ChannelList,
  MessageInput,
  MessageList,
  Thread,
  Window,
} from 'stream-chat-react';

import 'stream-chat-react/dist/css/v2/index.css';
import './layout.css';
import { useEffect } from 'react';
import EncryptedMessage from './EncryptedMessage';
import { useSealdContext } from './contexts/SealdContext';

const apiKey = 'qpvbxh63nz6h';
const userId = 'TestUser';
const userName = 'TestUser';
const userToken =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiVGVzdFVzZXIifQ.GxZc2Q3CDNAXIYe_vAGoXEwVWUV4L9BspumCU4DF4Qw';

const user: User = {
  id: userId,
  name: userName,
  image: `https://getstream.io/random_png/?name=${userName}`,
};

const sort: ChannelSort = { last_message_at: -1 };
const filters: ChannelFilters = {
  type: 'messaging',
  members: { $in: [userId] },
};
const options: ChannelOptions = {
  limit: 10,
};

const App = () => {
  const { loadingState, initializeSeald, encryptMessage } = useSealdContext();

  const client = useCreateChatClient({
    apiKey,
    tokenOrProvider: userToken,
    userData: user,
  });

  useEffect(() => {
    initializeSeald(userId, 'password');
  }, [initializeSeald]);

  if (!client) return <div>Setting up client & connection...</div>;

  if (loadingState === 'loading') return <div>Loading Seald...</div>;

  return (
    <Chat client={client}>
      <ChannelList filters={filters} sort={sort} options={options} />
      <Channel Message={EncryptedMessage}>
        <Window>
          <ChannelHeader />
          <MessageList />
          <MessageInput
            overrideSubmitHandler={async (
              message,
              channelId,
              customMessageData,
              options
            ) => {
              const messageToSend = message.text;
              const extractedChannelId = channelId.split(':')[1];

              if (messageToSend) {
                await encryptMessage(
                  messageToSend,
                  extractedChannelId,
                  client,
                  customMessageData,
                  options
                );
              }
            }}
          />
        </Window>
        <Thread />
      </Channel>
    </Chat>
  );
};

export default App;
