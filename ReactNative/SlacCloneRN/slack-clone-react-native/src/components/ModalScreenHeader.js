import React from 'react';
import {TouchableOpacity, View, StyleSheet} from 'react-native';
import {useTheme} from '@react-navigation/native';
import {useSafeAreaInsets} from 'react-native-safe-area-context';
import {SCText} from './SCText';

export const ModalScreenHeader = ({goBack, title, subTitle}) => {
  const {colors} = useTheme();
  const insets = useSafeAreaInsets();

  return (
    <View
      style={[
        styles.container,
        {
          backgroundColor: colors.background,
          paddingTop: insets.top > 0 ? 10 : 5,
        },
      ]}>
      <View style={styles.leftContent}>
        <TouchableOpacity
          onPress={() => {
            goBack && goBack();
          }}>
          <SCText style={styles.hamburgerIcon}>✕</SCText>
        </TouchableOpacity>
      </View>
      <View>
        <SCText style={styles.channelTitle}>{title}</SCText>
        {subTitle && (
          <SCText style={styles.channelSubTitle}>{subTitle}</SCText>
        )}
      </View>
      <View style={{width: 50}} />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    padding: 15,
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    borderBottomWidth: 0.5,
    borderBottomColor: 'grey',
  },
  leftContent: {
    position: 'absolute',
    left: 20,
  },
  hamburgerIcon: {
    fontSize: 20,
  },
  channelTitle: {
    textAlign: 'center',
    fontWeight: '900',
    fontSize: 17,
  },
  channelSubTitle: {
    textAlign: 'center',
    fontWeight: '900',
    fontSize: 13,
  },
});
