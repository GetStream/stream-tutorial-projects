/**
 * MessageAvatar - Legacy component
 *
 * Avatar rendering is now handled inline within the MessageSlack component.
 *
 * Kept for reference purposes.
 */
import React from 'react';
import {Image, View, StyleSheet} from 'react-native';

export const MessageAvatar = ({message, isTopOrSingle}) => {
  if (!message?.user?.image) {
    return <View style={styles.avatarSpacer} />;
  }

  if (isTopOrSingle) {
    return (
      <Image source={{uri: message.user.image}} style={styles.avatar} />
    );
  }

  return <View style={styles.avatarSpacer} />;
};

const styles = StyleSheet.create({
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
});
