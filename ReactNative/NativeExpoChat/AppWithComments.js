import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createStackNavigator } from '@react-navigation/stack';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Text } from 'react-native';
// A hook to connect the user to the chat client. It should be integrated into the NavigationStack and returns a flag to check if the chat client is ready.
import { useChatClient } from './useChatClient';
// Makes the gesture recognize immediately available when the app launches
import { GestureHandlerRootView } from 'react-native-gesture-handler';
// Make the current stored channel and thread available in the NavigationStack
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

// Create a stack navigator to navigate between the ChannelListScreen, ChannelScreen, and ThreadScreen components
const Stack = createStackNavigator();

// Create a chat client instance using the Stream Chat API key
const chatClient = StreamChat.getInstance(chatApiKey);

// Filter the channels to only show the channels where the user is a member
const filters = {
  members: {
    '$in': [chatUserId]
  },
};

// Sort the channels by the last message date
const sort = {
  last_message_at: -1,
};

// Configure the ChannelListScreen component. Used to display the channel list in the app. The ChannelListScreen component wraps the ChannelList component. The ChannelList component is used to display the channel list in the app.
const ChannelListScreen = props => {
  const { setChannel } = useAppContext();
  return (
    <ChannelList
    // onSelect function is used to navigate to the ChannelScreen component when a channel is selected
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

// Configure the channel screen
// The ChannelScreen component is used to display the channel messages in the app. The ChannelScreen component wraps the Channel component, the MessageList component, and the MessageInput component. The Channel component is used to display the channel messages in the app. The MessageList component is used to display the messages in the app. The MessageInput component is used to send messages in the app.
// The channel screen has 3 components
const ChannelScreen = props => {
  const { navigation } = props;
  const { channel, setThread } = useAppContext();

  return (
    // Hold data related to a channel and thread. Check if the channel ID is available
    <Channel channel={channel}>
      <MessageList // Render the messages in the channel
        onThreadSelect={(message) => { // This function is called when a user selects a thread reply
          if (channel?.id) { 
            setThread(message);
            navigation.navigate('ThreadScreen');
          }
        }}
      />
      <MessageInput /> // Render the message composer to send messages in a channel
    </Channel>
  );
}

// Configure the threads screen
// The ThreadScreen component is used to display the thread messages in the app. The ThreadScreen component wraps the Channel component and the Thread component. The Channel component is used to display the channel messages in the app. The Thread component is used to display the thread messages in the app.
const ThreadScreen = props => {
  const { channel, thread } = useAppContext();
  return (
    // Wrap the Thread component with the Channel component to display the thread messages in the app
    <Channel channel={channel} thread={thread} threadList>
      <Thread />
    </Channel>
  );
}

// The NavigationStack component is used to configure the navigation stack for the app. The NavigationStack component wraps the Chat component and the OverlayProvider component. The Chat component is the root component of the Stream Chat SDK. It wraps the entire app and provides the chat client to all components in the app. The OverlayProvider component is used to display the overlay components reactions view, fullscreen image preview, and attachment preview.
const NavigationStack = () => {
  // A flag to check if the chat client is ready
  const { clientIsReady } = useChatClient();

  if (!clientIsReady) {
    return <Text>Loading chat ...</Text>
}

  return (
    // Displays with a long press gesture to show reactions, threads, and actions on messages
    // OverlayProvider is used in the app's root and outside of the navigation stack to display the overlay components reactions view, fullscreen image preview, and attachment preview.
    <OverlayProvider>
      // Configure the Chat Component. The Chat component is the root component of the Stream Chat SDK. It wraps the entire app and provides the chat client to all components in the app.
      <Chat client={chatClient}>
        <Stack.Navigator>
          // 
        <Stack.Screen name="ChannelList" component={ChannelListScreen} />
        <Stack.Screen name="ChannelScreen" component={ChannelScreen} />
        <Stack.Screen name="ThreadScreen" component={ThreadScreen} />
        </Stack.Navigator>
      </Chat>
    </OverlayProvider>
  );
};

// Wrap the default component with the AppProvider and GestureHandlerRootView to use the AppContext and make the gesture available immediately
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
