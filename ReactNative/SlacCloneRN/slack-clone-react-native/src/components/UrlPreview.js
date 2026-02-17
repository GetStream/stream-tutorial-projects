/**
 * UrlPreview - Legacy component
 *
 * URL preview rendering is now handled inline within the MessageSlack component.
 * The MessageSlack component checks for og_scrape_url or title_link and renders
 * the preview directly.
 *
 * Kept for reference purposes.
 */
import React from 'react';
import {View, Image, StyleSheet} from 'react-native';
import {SCText} from './SCText';

export const UrlPreview = ({attachment}) => {
  if (!attachment) {
    return null;
  }

  return (
    <View style={styles.urlPreviewContainer}>
      <SCText style={styles.urlPreviewDomain}>
        {attachment.title_link?.replace(/https?:\/\//, '').split('/')[0]}
      </SCText>
      <SCText style={styles.urlPreviewTitle}>{attachment.title}</SCText>
      <SCText style={styles.urlPreviewDescription}>{attachment.text}</SCText>
      {attachment.image_url && (
        <Image
          source={{uri: attachment.image_url}}
          style={styles.urlPreviewImage}
          resizeMode="cover"
        />
      )}
    </View>
  );
};

const styles = StyleSheet.create({
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
});
