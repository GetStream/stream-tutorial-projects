import React, {useEffect, useState} from 'react';
import {View, SafeAreaView, StyleSheet} from 'react-native';
import {
  Channel,
  Thread,
} from 'stream-chat-react-native';

import {useNavigation, useRoute, useTheme} from '@react-navigation/native';

import {MessageSlack} from '../components/MessageSlack';
import {
  getChannelDisplayName,
  ChatClientService,
  truncate,
} from '../utils';
import {ModalScreenHeader} from '../components/ModalScreenHeader';

export function ThreadScreen() {
  const {params} = useRoute();
  const channelId = params?.channelId ?? null;
  const threadId = params?.threadId ?? null;
  const {colors} = useTheme();
  const chatClient = ChatClientService.getClient();
  const navigation = useNavigation();

  const [channel, setChannel] = useState(null);
  const [thread, setThread] = useState();
  const [isReady, setIsReady] = useState(false);

  const goBack = () => {
    navigation.goBack();
  };

  useEffect(() => {
    const getThread = async () => {
      const res = await chatClient.getMessage(threadId);
      setThread(res.message);
    };
    getThread();
  }, [chatClient, threadId]);

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
  }, [channelId, threadId]);

  if (!isReady || !thread || !channel) {
    return null;
  }

  return (
    <SafeAreaView style={{backgroundColor: colors.background}}>
      <View style={styles.channelScreenContainer}>
        <ModalScreenHeader
          title={'Thread'}
          goBack={goBack}
          subTitle={truncate(getChannelDisplayName(channel, true), 35)}
        />
        <View
          style={[styles.chatContainer, {backgroundColor: colors.background}]}>
          <Channel
            channel={channel}
            thread={thread}
            threadList
            keyboardVerticalOffset={80}
            MessageSimple={MessageSlack}
            forceAlignMessages="left"
            allowThreadMessagesInChannel>
            <Thread />
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
