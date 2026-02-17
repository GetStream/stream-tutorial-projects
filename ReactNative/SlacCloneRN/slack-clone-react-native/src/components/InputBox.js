/**
 * InputBox - Legacy component
 *
 * This component is no longer used directly. In stream-chat-react-native v8,
 * the MessageInput component handles input rendering internally.
 * Customization is done via Channel props like `Input` or `additionalTextInputProps`.
 *
 * Kept for reference purposes.
 */
import React from 'react';
import {TouchableOpacity, View, StyleSheet} from 'react-native';
import {SCText} from './SCText';
import {useTheme} from '@react-navigation/native';
import {SVGIcon} from './SVGIcon';

export const InputBox = ({onAtPress, onPickFile, onPickImage, children}) => {
  const {colors} = useTheme();

  return (
    <View style={[styles.container, {backgroundColor: colors.background}]}>
      {children}
      <View
        style={[styles.actionsContainer, {backgroundColor: colors.background}]}>
        <View style={styles.row}>
          <TouchableOpacity onPress={onAtPress}>
            <SCText style={styles.textActionLabel}>@</SCText>
          </TouchableOpacity>
          <TouchableOpacity style={styles.textEditorContainer}>
            <SCText style={styles.textActionLabel}>Aa</SCText>
          </TouchableOpacity>
        </View>
        <View style={styles.row}>
          <TouchableOpacity
            onPress={onPickFile}
            style={styles.fileAttachmentIcon}>
            <SVGIcon type="file-attachment" height="18" width="18" />
          </TouchableOpacity>
          <TouchableOpacity
            onPress={onPickImage}
            style={styles.imageAttachmentIcon}>
            <SVGIcon type="image-attachment" height="18" width="18" />
          </TouchableOpacity>
        </View>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flexDirection: 'column',
    width: '100%',
    height: 60,
  },
  actionsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  row: {flexDirection: 'row'},
  textActionLabel: {
    fontSize: 18,
  },
  textEditorContainer: {
    marginLeft: 10,
  },
  fileAttachmentIcon: {
    marginRight: 10,
    marginLeft: 10,
    alignSelf: 'center',
  },
  imageAttachmentIcon: {
    marginRight: 10,
    marginLeft: 10,
    alignSelf: 'flex-end',
  },
});
