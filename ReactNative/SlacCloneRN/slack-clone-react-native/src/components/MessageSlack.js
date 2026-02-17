import React from 'react';
import {View, StyleSheet, Image, TouchableOpacity, Text} from 'react-native';
import {useMessageContext} from 'stream-chat-react-native';
import moment from 'moment';
import {useTheme} from '@react-navigation/native';
import {SCText} from './SCText';

export const MessageSlack = () => {
  const {message, groupStyles, isMyMessage} = useMessageContext();
  const {colors} = useTheme();

  if (message.deleted_at) {
    return null;
  }

  const isTopOrSingle =
    groupStyles?.[0] === 'single' || groupStyles?.[0] === 'top';

  return (
    <View style={styles.container}>
      {isTopOrSingle ? (
        <Image
          source={{uri: message.user?.image}}
          style={styles.avatar}
        />
      ) : (
        <View style={styles.avatarSpacer} />
      )}
      <View style={styles.messageContent}>
        {isTopOrSingle && (
          <View style={styles.userBar}>
            <SCText style={[styles.userName, {color: colors.boldText}]}>
              {message.user?.name || message.user?.id}
            </SCText>
            <SCText style={styles.messageDate}>
              {moment(message.created_at).format('hh:mm A')}
            </SCText>
          </View>
        )}
        {message.text ? (
          <SCText style={[styles.messageText, {color: colors.text}]}>
            {message.text}
          </SCText>
        ) : null}
        {message.attachments?.map((attachment, index) => {
          if (attachment.type === 'giphy') {
            return (
              <View key={index} style={styles.giphyContainer}>
                <SCText style={styles.giphyTitle}>{attachment.title}</SCText>
                <SCText style={styles.giphySubtitle}>
                  Posted using Giphy.com
                </SCText>
                <Image
                  source={{uri: attachment.image_url || attachment.thumb_url}}
                  style={styles.giphyImage}
                />
              </View>
            );
          }
          if (attachment.og_scrape_url || attachment.title_link) {
            return (
              <View key={index} style={styles.urlPreviewContainer}>
                <SCText style={styles.urlPreviewDomain}>
                  {attachment.title_link?.replace(/https?:\/\//, '').split('/')[0]}
                </SCText>
                <SCText style={styles.urlPreviewTitle}>
                  {attachment.title}
                </SCText>
                <SCText style={styles.urlPreviewDescription}>
                  {attachment.text}
                </SCText>
                {attachment.image_url && (
                  <Image
                    source={{uri: attachment.image_url}}
                    style={styles.urlPreviewImage}
                    resizeMode="cover"
                  />
                )}
              </View>
            );
          }
          if (attachment.type === 'image') {
            return (
              <Image
                key={index}
                source={{uri: attachment.image_url || attachment.thumb_url}}
                style={styles.attachmentImage}
                resizeMode="cover"
              />
            );
          }
          return null;
        })}
        <MessageReactions message={message} />
        {message.reply_count > 0 && (
          <TouchableOpacity>
            <SCText style={styles.replyCount}>
              {message.reply_count}{' '}
              {message.reply_count === 1 ? 'reply' : 'replies'}
            </SCText>
          </TouchableOpacity>
        )}
      </View>
    </View>
  );
};

const MessageReactions = ({message}) => {
  const {dark} = useTheme();

  if (
    !message.reaction_counts ||
    Object.keys(message.reaction_counts).length === 0
  ) {
    return null;
  }

  return (
    <View style={styles.reactionListContainer}>
      {Object.entries(message.reaction_counts).map(([type, count]) => {
        const ownReactionTypes = (message.own_reactions || []).map(r => r.type);
        const isOwnReaction = ownReactionTypes.includes(type);
        return (
          <View
            key={type}
            style={[
              styles.reactionItemContainer,
              {
                borderColor: dark
                  ? isOwnReaction
                    ? '#313538'
                    : '#1E1D21'
                  : isOwnReaction
                  ? '#0064e2'
                  : 'transparent',
                backgroundColor: dark
                  ? isOwnReaction
                    ? '#194B8A'
                    : '#1E1D21'
                  : isOwnReaction
                  ? '#d6ebff'
                  : '#F0F0F0',
              },
            ]}>
            <Text
              style={[
                styles.reactionItem,
                {color: dark ? '#CFD4D2' : '#0064c2'},
              ]}>
              {getReactionEmoji(type)} {count}
            </Text>
          </View>
        );
      })}
    </View>
  );
};

const getReactionEmoji = type => {
  const emojiMap = {
    like: '👍',
    love: '❤️',
    haha: '😂',
    wow: '😮',
    sad: '😢',
    angry: '😡',
    '+1': '👍',
    '-1': '👎',
    heart: '❤️',
    laughing: '😂',
    joy: '😂',
    fire: '🔥',
    rocket: '🚀',
    thumbsup: '👍',
    thumbsdown: '👎',
  };
  return emojiMap[type] || '👍';
};

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    paddingHorizontal: 10,
    paddingVertical: 2,
  },
  avatar: {
    width: 36,
    height: 36,
    borderRadius: 5,
    marginRight: 10,
    marginTop: 3,
  },
  avatarSpacer: {
    width: 36,
    marginRight: 10,
  },
  messageContent: {
    flex: 1,
  },
  userBar: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 3,
  },
  userName: {
    fontWeight: '900',
    fontSize: 15,
    fontFamily: 'Lato-Bold',
  },
  messageDate: {
    color: 'grey',
    marginLeft: 6,
    fontSize: 10,
  },
  messageText: {
    fontSize: 16,
    fontFamily: 'Lato-Regular',
    lineHeight: 22,
  },
  replyCount: {
    color: '#0064c2',
    fontSize: 13,
    marginTop: 5,
    marginBottom: 5,
  },
  giphyContainer: {
    borderLeftWidth: 5,
    borderLeftColor: '#E4E4E4',
    paddingLeft: 10,
    marginTop: 5,
    marginBottom: 10,
  },
  giphyTitle: {
    fontWeight: 'bold',
    color: '#1E75BE',
    padding: 2,
  },
  giphySubtitle: {
    padding: 2,
    fontSize: 13,
    fontWeight: '300',
  },
  giphyImage: {
    height: 150,
    width: 250,
    borderRadius: 10,
  },
  urlPreviewContainer: {
    borderLeftWidth: 5,
    borderLeftColor: '#E4E4E4',
    paddingLeft: 10,
    marginTop: 5,
  },
  urlPreviewDomain: {
    fontWeight: 'bold',
    padding: 2,
  },
  urlPreviewTitle: {
    fontWeight: 'bold',
    color: '#1E75BE',
    padding: 2,
  },
  urlPreviewDescription: {
    padding: 2,
  },
  urlPreviewImage: {
    width: '100%',
    height: 150,
    marginTop: 5,
  },
  attachmentImage: {
    width: '95%',
    height: 200,
    borderRadius: 8,
    marginTop: 5,
    marginLeft: 5,
  },
  reactionListContainer: {
    flexDirection: 'row',
    alignSelf: 'flex-start',
    alignItems: 'center',
    marginTop: 5,
    marginBottom: 5,
    flexWrap: 'wrap',
  },
  reactionItemContainer: {
    borderWidth: 1,
    padding: 4,
    paddingLeft: 8,
    paddingRight: 8,
    borderRadius: 17,
    marginRight: 6,
    marginTop: 3,
  },
  reactionItem: {
    fontSize: 14,
  },
});
