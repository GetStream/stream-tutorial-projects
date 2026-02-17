import React, {useContext, useEffect, useState} from 'react';
import {
  Modal,
  TouchableHighlight,
  View,
  StyleSheet,
  FlatList,
  Image,
} from 'react-native';
import {ChatClientService, ChatUserContext, USERS} from '../utils';
import {useTheme} from '@react-navigation/native';
import {SCText} from './SCText';

export const UserPicker = props => {
  const [modalVisible, setModalVisible] = useState(props.modalVisible);
  const chatClient = ChatClientService.getClient();
  const {switchUser} = useContext(ChatUserContext);
  const {colors} = useTheme();

  useEffect(() => {
    setModalVisible(props.modalVisible);
  }, [props.modalVisible]);

  return (
    <Modal
      animationType="fade"
      transparent={true}
      visible={modalVisible}
      onRequestClose={() => {
        setModalVisible(false);
        props.onRequestClose();
      }}>
      <TouchableHighlight
        style={styles.container}
        onPress={() => {
          props.onRequestClose();
        }}
        underlayColor={'#333333cc'}>
        <View>
          <SCText
            style={{
              padding: 20,
              backgroundColor: colors.primary,
              color: colors.textInverted,
              fontWeight: '900',
            }}>
            Switch User
          </SCText>
          <FlatList
            style={{height: 420}}
            data={Object.values(USERS)}
            keyExtractor={(_, index) => index.toString()}
            renderItem={({item}) => {
              return (
                <TouchableHighlight
                  underlayColor={'transparent'}
                  onPress={() => {
                    switchUser(item[props.value]);
                    props.onRequestClose();
                  }}>
                  <View
                    style={{
                      flexDirection: 'row',
                      padding: 10,
                      backgroundColor: colors.backgroundSecondary,
                      alignItems: 'center',
                    }}>
                    <Image
                      source={{uri: item.image}}
                      style={{height: 35, width: 35}}
                    />
                    <View>
                      <SCText style={{color: colors.text, paddingLeft: 20}}>
                        {item.name}{' '}
                        {item.id === chatClient?.user?.id ? (
                          <SCText
                            style={{
                              fontStyle: 'italic',
                              fontSize: 12,
                              color: '#32CD32',
                            }}>
                            (current)
                          </SCText>
                        ) : (
                          ''
                        )}
                      </SCText>
                      <SCText
                        style={{
                          color: colors.linkText,
                          fontSize: 13,
                          paddingLeft: 20,
                        }}>
                        @{item.id}
                      </SCText>
                    </View>
                  </View>
                </TouchableHighlight>
              );
            }}
          />
        </View>
      </TouchableHighlight>
    </Modal>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    backgroundColor: '#333333cc',
    padding: 16,
  },
});
