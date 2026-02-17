/**
 * MessageActionSheet - Legacy component
 *
 * In stream-chat-react-native v8, message actions are handled by the SDK's
 * built-in overlay system (OverlayProvider). Long-pressing a message shows
 * actions automatically.
 *
 * This is a simplified version kept for reference purposes.
 * The original used react-native-actionsheet which is no longer a dependency.
 */
import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  Modal,
  TouchableOpacity,
  TouchableHighlight,
} from 'react-native';
import {SCText} from './SCText';
import {ChatClientService} from '../utils';
import {useTheme} from '@react-navigation/native';
import {SVGIcon} from './SVGIcon';
import Clipboard from '@react-native-clipboard/clipboard';

export const MessageActionSheet = ({
  message,
  visible,
  onClose,
  handleEdit,
  handleDelete,
  handleReaction,
  openThread,
}) => {
  const chatClient = ChatClientService.getClient();
  const {colors, dark} = useTheme();

  if (!message || !visible) {
    return null;
  }

  const options = [];

  if (message.user?.id === chatClient?.user?.id) {
    options.push({
      id: 'edit',
      title: 'Edit Message',
      icon: 'edit-text',
      handler: handleEdit,
    });
    options.push({
      id: 'delete',
      title: 'Delete message',
      icon: 'delete-text',
      handler: handleDelete,
    });
  }

  options.push({
    id: 'copy',
    title: 'Copy Text',
    icon: 'copy-text',
    handler: () => {
      Clipboard.setString(message.text || '');
      onClose();
    },
  });
  options.push({
    id: 'reply',
    title: 'Reply in Thread',
    icon: 'threads',
    handler: () => {
      openThread && openThread();
      onClose();
    },
  });

  return (
    <Modal
      animationType="fade"
      transparent
      visible={visible}
      onRequestClose={onClose}>
      <TouchableHighlight
        style={styles.overlay}
        onPress={onClose}
        underlayColor="rgba(0,0,0,0.5)">
        <View
          style={[
            styles.actionSheetContainer,
            {backgroundColor: colors.background},
          ]}>
          {options.map(option => (
            <TouchableOpacity
              key={option.id}
              style={styles.actionItem}
              onPress={() => {
                option.handler && option.handler();
                onClose();
              }}>
              <SVGIcon height="20" width="20" type={option.icon} />
              <SCText
                style={[
                  styles.actionItemText,
                  {color: option.id === 'delete' ? '#E01E5A' : colors.text},
                ]}>
                {option.title}
              </SCText>
            </TouchableOpacity>
          ))}
        </View>
      </TouchableHighlight>
    </Modal>
  );
};

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.5)',
    justifyContent: 'flex-end',
  },
  actionSheetContainer: {
    borderTopLeftRadius: 15,
    borderTopRightRadius: 15,
    padding: 15,
    paddingBottom: 40,
  },
  actionItem: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 15,
  },
  actionItemText: {
    marginLeft: 20,
    fontSize: 16,
  },
});
