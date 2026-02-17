/**
 * MessageText - Legacy component
 *
 * Message text rendering is now handled inline within the MessageSlack component.
 *
 * Kept for reference purposes.
 */
import React from 'react';
import {SCText} from './SCText';
import {useTheme} from '@react-navigation/native';

export const MessageText = ({message}) => {
  const {colors} = useTheme();

  if (!message.text) {
    return null;
  }

  return (
    <SCText
      style={{
        fontSize: 16,
        fontFamily: 'Lato-Regular',
        lineHeight: 22,
        color: colors.text,
      }}>
      {message.text}
    </SCText>
  );
};
