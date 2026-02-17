import React, {useEffect, useState} from 'react';
import {View, SafeAreaView, StyleSheet} from 'react-native';
import {
  Channel,
  MessageList,
  MessageInput,
} from 'stream-chat-react-native';
import {useNavigation, useRoute, useTheme} from '@react-navigation/native';

import {ChannelHeader} from '../components/ChannelHeader';
import {MessageSlack} from '../components/MessageSlack';
import {DateSeparator} from '../components/DateSeparator';
import {
  getChannelDisplayImage,
  getChannelDisplayName,
  ChatClientService,
  AsyncStore,
} from '../utils';

export function ChannelScreen() {
  const {colors} = useTheme();
  const {params} = useRoute();
  const channelId = params?.channelId ?? null;
  const navigation = useNavigation();
  const chatClient = ChatClientService.getClient();
  const [channel, setChannel] = useState(null);
  const [isReady, setIsReady] = useState(false);

  const goBack = () => {
    navigation.goBack();
  };

  useEffect(() => {
    if (!channelId) {
      navigation.goBack();
      return;
    }
    const initChannel = async () => {
      const _channel = chatClient.channel('messaging', channelId);
      await _channel.watch();
      setChannel(_channel);
      setIsReady(true);
    };
    initChannel();
  }, [channelId]);

  if (!isReady || !channel) {
    return null;
  }

  return (
    <SafeAreaView style={{backgroundColor: colors.background}}>
      <View style={styles.channelScreenContainer}>
        <ChannelHeader goBack={goBack} channel={channel} />
        <View
          style={[styles.chatContainer, {backgroundColor: colors.background}]}>
          <Channel
            channel={channel}
            keyboardVerticalOffset={80}
            MessageSimple={MessageSlack}
            DateSeparator={DateSeparator}
            forceAlignMessages="left"
            doSendMessageRequest={async (cid, message) => {
              AsyncStore.removeItem(
                `@slack-clone-draft-${chatClient.user.id}-${channelId}`,
              );
              return channel.sendMessage(message);
            }}>
            <MessageList
              onThreadSelect={thread => {
                navigation.navigate('ThreadScreen', {
                  threadId: thread.id,
                  channelId: channel.id,
                });
              }}
            />
            <MessageInput
              additionalTextInputProps={{
                placeholderTextColor: '#979A9A',
                placeholder:
                  channel?.data?.name
                    ? 'Message #' +
                      channel.data.name.toLowerCase().replace(' ', '_')
                    : 'Message',
              }}
            />
          </Channel>
        </View>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  channelScreenContainer: {flexDirection: 'column', height: '100%'},
  chatContainer: {
    flexGrow: 1,
    flexShrink: 1,
  },
});
