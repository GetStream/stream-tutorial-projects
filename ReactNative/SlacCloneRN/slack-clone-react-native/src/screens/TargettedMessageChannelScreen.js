import {useNavigation, useRoute, useTheme} from '@react-navigation/native';
import React, {useEffect, useState} from 'react';
import {View, SafeAreaView, StyleSheet, Text, TouchableOpacity} from 'react-native';
import {Channel, MessageList} from 'stream-chat-react-native';
import {ChannelHeader} from '../components/ChannelHeader';
import {MessageSlack} from '../components/MessageSlack';
import {DateSeparator} from '../components/DateSeparator';
import {ChatClientService} from '../utils';

export const TargettedMessageChannelScreen = () => {
  const navigation = useNavigation();
  const {params} = useRoute();
  const message = params?.message ?? null;
  const {colors} = useTheme();
  const chatClient = ChatClientService.getClient();
  const [channel, setChannel] = useState(null);

  useEffect(() => {
    const initChannel = async () => {
      if (!message) {
        navigation.goBack();
        return;
      }
      const _channel = chatClient.channel('messaging', message.channel.id);
      await _channel.query({
        messages: {limit: 10, id_lte: message.id},
      });
      setChannel(_channel);
    };
    initChannel();
  }, [message]);

  if (!channel) {
    return null;
  }

  return (
    <SafeAreaView style={{backgroundColor: colors.background}}>
      <View style={styles.channelScreenContainer}>
        <ChannelHeader channel={channel} goBack={navigation.goBack} />
        <View style={styles.chatContainer}>
          <Channel
            channel={channel}
            MessageSimple={MessageSlack}
            DateSeparator={DateSeparator}
            forceAlignMessages="left">
            <MessageList
              additionalFlatListProps={{
                onEndReached: () => null,
              }}
            />
          </Channel>
        </View>
        <TouchableOpacity
          style={[styles.recentMessageLink, {backgroundColor: colors.primary}]}
          onPress={() => {
            navigation.navigate('ChannelScreen', {channelId: channel.id});
          }}>
          <Text style={styles.recentMessageLinkText}>
            Jump to recent message
          </Text>
        </TouchableOpacity>
      </View>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  channelScreenContainer: {flexDirection: 'column', height: '100%'},
  chatContainer: {flexGrow: 1, flexShrink: 1},
  recentMessageLink: {
    height: 60,
    alignSelf: 'center',
    width: '100%',
    paddingTop: 20,
  },
  recentMessageLinkText: {
    alignSelf: 'center',
    color: '#1E90FF',
    fontSize: 15,
  },
});
