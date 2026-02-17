import React, {useEffect, useState, useCallback} from 'react';
import {View, SafeAreaView, StyleSheet, TextInput} from 'react-native';
import {
  Channel,
  MessageList,
  MessageInput,
} from 'stream-chat-react-native';
import {useTheme} from '@react-navigation/native';

import {MessageSlack} from '../components/MessageSlack';
import {DateSeparator} from '../components/DateSeparator';
import {ModalScreenHeader} from '../components/ModalScreenHeader';

import {
  AsyncStore,
  ChatClientService,
  getChannelDisplayImage,
  getChannelDisplayName,
} from '../utils';
import {useNavigation} from '@react-navigation/native';
import {UserSearch} from '../components/UserSearch';

export const NewMessageScreen = () => {
  const [tags, setTags] = useState([]);
  const [channel, setChannel] = useState(null);
  const navigation = useNavigation();
  const chatClient = ChatClientService.getClient();
  const [focusOnSearch, setFocusOnSearch] = useState(true);
  const {colors} = useTheme();

  const goBack = () => {
    if (channel) {
      AsyncStore.setItem(
        `@slack-clone-draft-${chatClient.user.id}-${channel.id}`,
        {
          channelId: channel.id,
          image: getChannelDisplayImage(channel),
          title: getChannelDisplayName(channel),
          text: '',
        },
      );
    }
    navigation.goBack();
  };

  const createOrGetChannel = useCallback(
    async newTags => {
      if (newTags.length === 0) {
        setChannel(null);
        return;
      }
      const newChannel = chatClient.channel('messaging', {
        members: [...newTags.map(t => t.id), chatClient.user.id],
        name: '',
        example: 'slack-demo',
      });
      await newChannel.watch();
      setChannel(newChannel);
      setFocusOnSearch(false);
    },
    [chatClient],
  );

  return (
    <SafeAreaView style={{backgroundColor: colors.background, flex: 1}}>
      <View style={styles.channelScreenContainer}>
        <ModalScreenHeader goBack={goBack} title="New Message" />
        <UserSearch
          onFocus={() => setFocusOnSearch(true)}
          onChangeTags={newTags => {
            setTags(newTags);
            createOrGetChannel(newTags);
          }}
        />
        <View
          style={[styles.chatContainer, {backgroundColor: colors.background}]}>
          {channel && !focusOnSearch ? (
            <Channel
              channel={channel}
              MessageSimple={MessageSlack}
              DateSeparator={DateSeparator}
              forceAlignMessages="left">
              <MessageList />
              <MessageInput
                additionalTextInputProps={{
                  placeholderTextColor: colors.dimmedText,
                  placeholder: 'Start a new message',
                }}
              />
            </Channel>
          ) : (
            <View style={styles.placeholderContainer}>
              <TextInput
                style={[styles.placeholderInput, {color: colors.text}]}
                placeholder="Start a new message"
                placeholderTextColor={colors.dimmedText}
                onFocus={() => {
                  if (tags.length > 0) {
                    createOrGetChannel(tags);
                  }
                }}
              />
            </View>
          )}
        </View>
      </View>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  channelScreenContainer: {flexDirection: 'column', flex: 1},
  chatContainer: {
    flexGrow: 1,
    flexShrink: 1,
  },
  placeholderContainer: {
    flex: 1,
    justifyContent: 'flex-end',
  },
  placeholderInput: {
    padding: 15,
    borderTopWidth: 0.5,
    borderTopColor: '#979A9A',
    fontSize: 15,
  },
});
