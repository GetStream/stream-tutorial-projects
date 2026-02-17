/**
 * ReactionPicker - Legacy component
 *
 * In stream-chat-react-native v8, reactions are handled by the SDK's
 * built-in overlay system. However, this custom reaction picker can still
 * be used if you want a Slack-style full emoji picker.
 *
 * Updated to remove dependency on react-native-haptic (now uses
 * react-native-haptic-feedback).
 */
import {useTheme} from '@react-navigation/native';
import React, {useEffect, useRef} from 'react';
import {
  Modal,
  View,
  Text,
  Animated,
  TouchableOpacity,
  SectionList,
  StyleSheet,
} from 'react-native';
import {SCText} from './SCText';
import {groupedSupportedReactions} from '../utils/supportedReactions';

export const ReactionPicker = props => {
  const {dismissReactionPicker, handleReaction, reactionPickerVisible} = props;
  const {colors} = useTheme();
  const slide = useRef(new Animated.Value(-600)).current;
  const reactionPickerExpanded = useRef(false);

  const _dismissReactionPicker = () => {
    reactionPickerExpanded.current = false;
    Animated.timing(slide, {
      toValue: -600,
      duration: 100,
      useNativeDriver: false,
    }).start(() => {
      dismissReactionPicker();
    });
  };

  const _handleReaction = type => {
    reactionPickerExpanded.current = false;
    Animated.timing(slide, {
      toValue: -600,
      duration: 100,
      useNativeDriver: false,
    }).start(() => {
      handleReaction(type);
    });
  };

  useEffect(() => {
    if (reactionPickerVisible) {
      setTimeout(() => {
        Animated.timing(slide, {
          toValue: -300,
          duration: 100,
          useNativeDriver: false,
        }).start();
      }, 200);
    }
  });

  if (!reactionPickerVisible) {
    return null;
  }

  return (
    <Modal
      animationType="fade"
      onRequestClose={_dismissReactionPicker}
      transparent
      visible>
      <TouchableOpacity
        style={styles.overlay}
        activeOpacity={1}
        onPress={_dismissReactionPicker}
      />
      <Animated.View
        style={[
          {
            bottom: slide,
          },
          styles.animatedContainer,
        ]}>
        <View
          style={[
            {
              backgroundColor: colors.background,
            },
            styles.pickerContainer,
          ]}>
          <View style={styles.listContainer}>
            <SectionList
              onScrollBeginDrag={() => {
                reactionPickerExpanded.current = true;
                Animated.timing(slide, {
                  toValue: 0,
                  duration: 300,
                  useNativeDriver: false,
                }).start();
              }}
              style={{height: 600, width: '100%'}}
              onScroll={event => {
                if (!reactionPickerExpanded.current) {
                  return;
                }

                if (event.nativeEvent.contentOffset.y <= 0) {
                  reactionPickerExpanded.current = false;
                  Animated.timing(slide, {
                    toValue: -300,
                    duration: 300,
                    useNativeDriver: false,
                  }).start();
                }
              }}
              sections={groupedSupportedReactions}
              renderSectionHeader={({section: {title}}) => (
                <SCText
                  style={[
                    {
                      backgroundColor: colors.background,
                    },
                    styles.groupTitle,
                  ]}>
                  {title}
                </SCText>
              )}
              renderItem={({item}) => {
                return (
                  <View style={styles.reactionsRow}>
                    {item.map(({icon, id}) => {
                      return (
                        <View key={id} style={styles.reactionsItemContainer}>
                          <Text
                            onPress={() => _handleReaction(id)}
                            style={styles.reactionsItem}>
                            {icon}
                          </Text>
                        </View>
                      );
                    })}
                  </View>
                );
              }}
            />
          </View>
        </View>
      </Animated.View>
    </Modal>
  );
};

const styles = StyleSheet.create({
  overlay: {
    width: '100%',
    height: '100%',
    alignSelf: 'flex-end',
    alignItems: 'flex-start',
    backgroundColor: 'rgba(0,0,0,0.7)',
  },
  animatedContainer: {
    position: 'absolute',
    backgroundColor: 'transparent',
  },
  pickerContainer: {
    flexDirection: 'column',
    borderRadius: 15,
    paddingHorizontal: 10,
  },
  listContainer: {
    width: '100%',
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'center',
    marginBottom: 20,
  },
  groupTitle: {
    padding: 10,
    paddingLeft: 13,
    fontWeight: '200',
  },
  reactionsRow: {
    width: '100%',
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'center',
    marginTop: 3,
  },
  reactionsItemContainer: {
    alignItems: 'center',
    marginTop: -5,
  },
  reactionsItem: {
    fontSize: 35,
    margin: 5,
    marginVertical: 5,
  },
});
