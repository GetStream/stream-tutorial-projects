import React, {useState, useEffect} from 'react';
import {
  View,
  StyleSheet,
  TouchableOpacity,
  Image,
  ActivityIndicator,
  FlatList,
} from 'react-native';

import {ChatClientService} from '../utils';
import {NewMessageBubble} from '../components/NewMessageBubble';
import {ScreenHeader} from './ScreenHeader';
import {useTheme, useNavigation} from '@react-navigation/native';
import {SCText} from '../components/SCText';

export const MentionsScreen = () => {
  const chatClient = ChatClientService.getClient();
  const [results, setResults] = useState([]);
  const [loadingResults, setLoadingResults] = useState(true);
  const navigation = useNavigation();
  const {colors} = useTheme();

  useEffect(() => {
    const getMessages = async () => {
      try {
        const res = await chatClient.search(
          {members: {$in: [chatClient.user.id]}},
          `@${chatClient.user.name}`,
        );
        setResults(res.results);
      } catch (e) {
        setResults([]);
      }
      setLoadingResults(false);
    };
    getMessages();
  }, []);

  return (
    <View style={[styles.container, {backgroundColor: colors.background}]}>
      <ScreenHeader title="Mentions" />
      {loadingResults && (
        <View style={styles.loadingIndicatorContainer}>
          <ActivityIndicator size="small" color={colors.text} />
        </View>
      )}
      {!loadingResults && (
        <View style={styles.resultsContainer}>
          <FlatList
            showsVerticalScrollIndicator={false}
            data={results}
            renderItem={({item}) => (
              <TouchableOpacity
                onPress={() => {
                  navigation.navigate('TargettedMessageChannelScreen', {
                    message: item.message,
                  });
                }}
                style={styles.resultItemContainer}>
                <View
                  style={[
                    styles.mentionDetails,
                    {borderTopColor: colors.border},
                  ]}>
                  <SCText style={styles.mentionerName}>
                    {item.message.user.name}{' '}
                  </SCText>
                  <SCText style={styles.mentionActivity}>
                    mentioned you in #
                    {item.message.channel?.name
                      ?.toLowerCase()
                      ?.replace(' ', '_') || 'channel'}
                  </SCText>
                </View>
                <View style={styles.messageContainer}>
                  <Image
                    style={styles.messageUserImage}
                    source={{uri: item.message.user.image}}
                  />
                  <View style={styles.messageDetailsContainer}>
                    <SCText
                      style={[
                        styles.messageUserName,
                        {color: colors.boldText},
                      ]}>
                      {item.message.user.name}
                    </SCText>
                    <SCText>{item.message.text}</SCText>
                  </View>
                </View>
              </TouchableOpacity>
            )}
          />
        </View>
      )}
      <NewMessageBubble />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {flex: 1},
  loadingIndicatorContainer: {flex: 1, justifyContent: 'center'},
  resultsContainer: {flex: 1, flexGrow: 1, flexShrink: 1},
  resultItemContainer: {marginLeft: 10},
  mentionDetails: {
    padding: 20,
    paddingLeft: 40,
    paddingBottom: 10,
    borderTopWidth: 0.5,
    flexDirection: 'row',
  },
  mentionerName: {fontWeight: '700', fontSize: 13, color: '#696969'},
  mentionActivity: {fontSize: 13, color: '#696969'},
  messageContainer: {flexDirection: 'row', marginTop: 5, marginBottom: 5},
  messageUserImage: {height: 30, width: 30, borderRadius: 5},
  messageDetailsContainer: {marginLeft: 10, marginBottom: 15},
  messageUserName: {fontWeight: '900'},
});
