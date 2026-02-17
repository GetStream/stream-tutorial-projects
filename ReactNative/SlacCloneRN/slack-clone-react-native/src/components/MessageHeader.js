/**
 * MessageHeader - Legacy component
 *
 * Message header (user name + timestamp) rendering is now handled inline
 * within the MessageSlack component.
 *
 * Kept for reference purposes.
 */
import React from 'react';
import {View, StyleSheet} from 'react-native';
import moment from 'moment';
import {SCText} from './SCText';
import {useTheme} from '@react-navigation/native';

export const MessageHeader = ({message}) => {
  const {colors} = useTheme();

  return (
    <View style={styles.userBar}>
      <SCText style={[styles.userName, {color: colors.boldText}]}>
        {message.user?.name || message.user?.id}
      </SCText>
      <SCText style={styles.messageDate}>
        {moment(message.created_at).format('hh:mm A')}
      </SCText>
    </View>
  );
};

const styles = StyleSheet.create({
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
});
