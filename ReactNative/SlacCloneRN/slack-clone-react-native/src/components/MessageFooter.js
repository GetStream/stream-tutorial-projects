/**
 * MessageFooter - Legacy component
 *
 * Message footer (reactions + reply count) rendering is now handled inline
 * within the MessageSlack component.
 *
 * Kept for reference purposes.
 */
import React from 'react';
import {View, TouchableOpacity, StyleSheet} from 'react-native';
import {SCText} from './SCText';

export const MessageFooter = ({message}) => {
  if (!message) {
    return null;
  }

  return (
    <View>
      {message.reply_count > 0 && (
        <TouchableOpacity>
          <SCText style={styles.replyCount}>
            {message.reply_count}{' '}
            {message.reply_count === 1 ? 'reply' : 'replies'}
          </SCText>
        </TouchableOpacity>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  replyCount: {
    color: '#0064c2',
    fontSize: 13,
    marginTop: 5,
    marginBottom: 5,
  },
});
