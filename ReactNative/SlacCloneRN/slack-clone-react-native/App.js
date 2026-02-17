import React, {useEffect, useState} from 'react';
import {
  ActivityIndicator,
  View,
  StyleSheet,
  SafeAreaView,
  Text,
  Pressable,
  LogBox,
  useColorScheme,
} from 'react-native';

import {SafeAreaProvider} from 'react-native-safe-area-context';
import {GestureHandlerRootView} from 'react-native-gesture-handler';

import {NavigationContainer} from '@react-navigation/native';
import {createStackNavigator} from '@react-navigation/stack';
import {createBottomTabNavigator} from '@react-navigation/bottom-tabs';

import {StreamChat} from 'stream-chat';
import {Chat, OverlayProvider} from 'stream-chat-react-native';

import {
  ChatUserContext,
  ChatClientService,
  USER_TOKENS,
  USERS,
} from './src/utils';

import {ChannelScreen} from './src/screens/ChannelScreen';
import {NewMessageScreen} from './src/screens/NewMessageScreen';
import {ChannelSearchScreen} from './src/screens/ChannelSearchScreen';
import {ChannelListScreen} from './src/screens/ChannelListScreen';
import {DraftsScreen} from './src/screens/DraftsScreen';
import {MentionsScreen} from './src/screens/MentionsSearch';
import {DirectMessagesScreen} from './src/screens/DirectMessagesScreen';
import {TargettedMessageChannelScreen} from './src/screens/TargettedMessageChannelScreen';
import {MessageSearchScreen} from './src/screens/MessageSearchScreen';
import {ProfileScreen} from './src/screens/ProfileScreen';
import {ThreadScreen} from './src/screens/ThreadScreen';

import {BottomTabs} from './src/components/BottomTabs';
import {DarkTheme, LightTheme} from './src/appTheme';

LogBox.ignoreAllLogs(true);

const Tab = createBottomTabNavigator();
const HomeStack = createStackNavigator();
const ModalStack = createStackNavigator();

const App = () => {
  const scheme = useColorScheme();
  const [connecting, setConnecting] = useState(true);
  const [connectionError, setConnectionError] = useState(null);
  const [retryCount, setRetryCount] = useState(0);
  const [user, setUser] = useState(USERS.vishal);

  useEffect(() => {
    let client;
    let isMounted = true;

    const initChat = async () => {
      try {
        client = StreamChat.getInstance('q95x9hkbyd6p', {
          timeout: 30000,
        });

        await client.connectUser(user, USER_TOKENS[user.id]);

        if (isMounted) {
          ChatClientService.setClient(client);
          setConnectionError(null);
          setConnecting(false);
        }
      } catch (error) {
        console.error('Failed to connect to Stream Chat:', error);
        if (isMounted) {
          setConnectionError(
            error?.message || 'Unable to connect. Check your network and retry.',
          );
          setConnecting(false);
        }
      }
    };

    setConnecting(true);
    setConnectionError(null);
    initChat();

    return () => {
      isMounted = false;
      if (client) {
        client.disconnectUser().catch(() => null);
      }
    };
  }, [user, retryCount]);

  if (connecting) {
    return (
      <SafeAreaView>
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="small" color="black" />
        </View>
      </SafeAreaView>
    );
  }

  if (connectionError) {
    return (
      <SafeAreaView>
        <View style={styles.loadingContainer}>
          <Text style={styles.errorTitle}>Could not connect to chat.</Text>
          <Text style={styles.errorBody}>{connectionError}</Text>
          <Pressable
            style={styles.retryButton}
            onPress={() => setRetryCount(count => count + 1)}>
            <Text style={styles.retryButtonText}>Retry</Text>
          </Pressable>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <GestureHandlerRootView style={styles.container}>
      <SafeAreaProvider>
        <OverlayProvider>
          <Chat client={ChatClientService.getClient()}>
            <NavigationContainer
              theme={scheme === 'dark' ? DarkTheme : LightTheme}>
              <ChatUserContext.Provider
                value={{
                  switchUser: userId => setUser(USERS[userId]),
                }}>
                <HomeStackNavigator />
              </ChatUserContext.Provider>
            </NavigationContainer>
          </Chat>
        </OverlayProvider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
};

const ModalStackNavigator = () => {
  return (
    <ModalStack.Navigator
      initialRouteName="Tabs"
      screenOptions={{
        presentation: 'modal',
        headerShown: false,
      }}>
      <ModalStack.Screen name="Tabs" component={TabNavigation} />
      <ModalStack.Screen
        name="NewMessageScreen"
        component={NewMessageScreen}
      />
      <ModalStack.Screen
        name="ChannelSearchScreen"
        component={ChannelSearchScreen}
      />
      <ModalStack.Screen
        name="MessageSearchScreen"
        component={MessageSearchScreen}
      />
      <ModalStack.Screen
        name="TargettedMessageChannelScreen"
        component={TargettedMessageChannelScreen}
      />
    </ModalStack.Navigator>
  );
};

const HomeStackNavigator = () => {
  return (
    <HomeStack.Navigator
      initialRouteName="ModalStack"
      screenOptions={{headerShown: false}}>
      <HomeStack.Screen name="ModalStack" component={ModalStackNavigator} />
      <HomeStack.Screen name="ChannelScreen" component={ChannelScreen} />
      <HomeStack.Screen name="DraftsScreen" component={DraftsScreen} />
      <HomeStack.Screen name="ThreadScreen" component={ThreadScreen} />
    </HomeStack.Navigator>
  );
};

const TabNavigation = () => {
  return (
    <Tab.Navigator
      tabBar={props => <BottomTabs {...props} />}
      screenOptions={{headerShown: false}}>
      <Tab.Screen name="home" component={ChannelListScreen} />
      <Tab.Screen name="dms" component={DirectMessagesScreen} />
      <Tab.Screen name="mentions" component={MentionsScreen} />
      <Tab.Screen name="you" component={ProfileScreen} />
    </Tab.Navigator>
  );
};

export default App;

const styles = StyleSheet.create({
  loadingContainer: {
    height: '100%',
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 20,
  },
  container: {
    flex: 1,
  },
  errorTitle: {
    fontSize: 17,
    fontWeight: '600',
    marginBottom: 8,
  },
  errorBody: {
    textAlign: 'center',
    marginBottom: 16,
  },
  retryButton: {
    backgroundColor: '#005FFF',
    borderRadius: 8,
    paddingHorizontal: 16,
    paddingVertical: 10,
  },
  retryButtonText: {
    color: '#fff',
    fontWeight: '600',
  },
});
