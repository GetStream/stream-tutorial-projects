import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createStackNavigator } from '@react-navigation/stack';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Text } from 'react-native';
import { useChatClient } from './useChatClient';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { AppProvider } from "./AppContext";
import {
  Chat,
  ChannelList,
  OverlayProvider,
  Channel,
  MessageList,
  MessageInput,
  Thread,
} from 'stream-chat-expo'; // stream-chat-react-native Or stream-chat-expo
import { StreamChat } from 'stream-chat';
import { chatApiKey, chatUserId } from './chatConfig';
import { useAppContext } from "./AppContext";

const Stack = createStackNavigator();
const chatClient = StreamChat.getInstance(chatApiKey);

const filters = {
  members: {
    '$in': [chatUserId]
  },
};

const sort = {
  last_message_at: -1,
};

const ChannelListScreen = props => {
  const { setChannel } = useAppContext();
  return (
    <ChannelList
      onSelect={(channel) => {
        const { navigation } = props;
        setChannel(channel);
        navigation.navigate('ChannelScreen');
      }}
      filters={filters}
      sort={sort}
    />
  );
}

const ChannelScreen = props => {
  const { navigation } = props;
  const { channel, setThread } = useAppContext();

  return (
    <Channel channel={channel}>
      <MessageList 
        onThreadSelect={(message) => {
          if (channel?.id) {
            setThread(message);
            navigation.navigate('ThreadScreen');
          }
        }}
      />
      <MessageInput />
    </Channel>
  );
}

const ThreadScreen = props => {
  const { channel, thread } = useAppContext();
  return (
    <Channel channel={channel} thread={thread} threadList>
      <Thread />
    </Channel>
  );
}

const NavigationStack = () => {
  const { clientIsReady } = useChatClient();

  if (!clientIsReady) {
    return <Text>Loading chat ...</Text>
}

  return (
    <OverlayProvider>
      <Chat client={chatClient}>
        <Stack.Navigator>
        <Stack.Screen name="ChannelList" component={ChannelListScreen} />
        <Stack.Screen name="ChannelScreen" component={ChannelScreen} />
        <Stack.Screen name="ThreadScreen" component={ThreadScreen} />
        </Stack.Navigator>
      </Chat>
    </OverlayProvider>
  );
};

export default () => {
  return (
    <AppProvider>
        <GestureHandlerRootView style={{ flex: 1 }}>
            <SafeAreaView style={{ flex: 1 }}>
                <NavigationContainer>
                    <NavigationStack />
                </NavigationContainer>
            </SafeAreaView>
        </GestureHandlerRootView>
    </AppProvider>
);
};
