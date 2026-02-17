/**
 * CustomKeyboardCompatibleView - Legacy component
 *
 * This component is no longer used directly. In stream-chat-react-native v8,
 * keyboard handling is built into the Channel component via the
 * keyboardVerticalOffset prop.
 *
 * Kept for reference purposes.
 */
import React from 'react';
import {KeyboardAvoidingView, Platform} from 'react-native';

export const CustomKeyboardCompatibleView = ({children}) => {
  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      style={{flex: 1}}>
      {children}
    </KeyboardAvoidingView>
  );
};
