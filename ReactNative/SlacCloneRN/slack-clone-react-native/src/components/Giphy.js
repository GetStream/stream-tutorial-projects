/**
 * Giphy - Legacy component
 *
 * Giphy card rendering is now handled inline within the MessageSlack component.
 * The MessageSlack component checks for attachment.type === 'giphy' and renders
 * the card directly.
 *
 * Kept for reference purposes.
 */
import React from 'react';
import {View, Image, StyleSheet} from 'react-native';
import {SCText} from './SCText';

export const Giphy = ({attachment}) => {
  if (!attachment) {
    return null;
  }

  return (
    <View style={styles.giphyContainer}>
      <SCText style={styles.giphyTitle}>{attachment.title}</SCText>
      <SCText style={styles.giphySubtitle}>Posted using Giphy.com</SCText>
      <Image
        source={{uri: attachment.image_url || attachment.thumb_url}}
        style={styles.giphyImage}
      />
    </View>
  );
};

const styles = StyleSheet.create({
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
});
