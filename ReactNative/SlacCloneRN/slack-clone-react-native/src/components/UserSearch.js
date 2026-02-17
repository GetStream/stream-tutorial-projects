import React, {useState} from 'react';
import {
  View,
  Image,
  TextInput,
  StyleSheet,
  TouchableOpacity,
  FlatList,
} from 'react-native';
import {CacheService, ChatClientService} from '../utils';
import {useTheme} from '@react-navigation/native';
import {SCText} from './SCText';

export const UserSearch = ({onChangeTags, onFocus}) => {
  const {colors, dark} = useTheme();
  const [searchText, setSearchText] = useState('');
  const [results, setResults] = useState(CacheService.getMembers());
  const [tags, setTags] = useState([]);
  const [focusOnTags, setFocusOnTags] = useState(true);

  const chatClient = ChatClientService.getClient();

  const addTag = tag => {
    if (!tag || !tag.name) {
      return;
    }
    const newTags = [...tags, tag];
    setTags(newTags);
    setSearchText('');
    onChangeTags(newTags);
  };

  const removeTag = index => {
    if (index < 0) {
      return;
    }
    const newTags = [...tags.slice(0, index), ...tags.slice(index + 1)];
    setTags(newTags);
    onChangeTags(newTags);
  };

  const onFocusSearchInput = async () => {
    setFocusOnTags(true);
    if (!searchText) {
      setResults(CacheService.getMembers());
    } else {
      const res = await chatClient.queryUsers(
        {name: {$autocomplete: searchText}},
        {last_active: -1},
        {presence: true},
      );
      setResults(res.users);
    }
    onFocus();
  };

  const onChangeSearchText = async text => {
    setSearchText(text);
    if (!text) {
      return setResults(CacheService.getMembers());
    }
    const res = await chatClient.queryUsers(
      {name: {$autocomplete: text}},
      {last_active: -1},
      {presence: true},
    );
    setResults(res.users);
  };

  return (
    <>
      <View style={styles.searchContainer}>
        <SCText style={styles.searchContainerLabel}>To:</SCText>
        <View style={styles.inputBoxContainer}>
          {tags.map((tag, index) => {
            if (!focusOnTags) {
              return (
                <SCText key={index} style={styles.blurredTagText}>
                  {tag.name},{' '}
                </SCText>
              );
            }
            return (
              <TouchableOpacity
                key={`${tag.name}-${index}`}
                onPress={() => removeTag(index)}
                style={[
                  styles.tagContainer,
                  {backgroundColor: dark ? '#152E44' : '#c4e2ff'},
                ]}>
                <Image style={styles.tagImage} source={{uri: tag.image}} />
                <SCText
                  style={[
                    styles.tagText,
                    {color: dark ? '#E5F5F9' : 'black'},
                  ]}>
                  {tag.name}
                </SCText>
              </TouchableOpacity>
            );
          })}
          <TextInput
            style={[styles.inputBox, {color: colors.text}]}
            autoFocus
            onFocus={onFocusSearchInput}
            onBlur={() => {
              setResults(null);
              setFocusOnTags(false);
            }}
            placeholder="Search for conversation"
            placeholderTextColor={colors.dimmedText}
            value={searchText}
            onChangeText={onChangeSearchText}
          />
        </View>
      </View>
      {results && results.length >= 0 && (
        <FlatList
          keyboardDismissMode="none"
          contentContainerStyle={{flexGrow: 1}}
          keyboardShouldPersistTaps="always"
          ListEmptyComponent={() => (
            <View style={styles.emptyResultIndicator}>
              <SCText>No user matches these keywords</SCText>
            </View>
          )}
          renderItem={({item}) => (
            <TouchableOpacity
              style={styles.searchResultContainer}
              onPress={() => addTag(item)}>
              <Image
                style={styles.searchResultUserImage}
                source={{uri: item.image}}
              />
              <SCText style={styles.searchResultUserName}>{item.name}</SCText>
            </TouchableOpacity>
          )}
          data={results}
        />
      )}
    </>
  );
};

const styles = StyleSheet.create({
  searchContainer: {
    display: 'flex',
    height: 50,
    flexDirection: 'row',
    alignItems: 'center',
    borderBottomColor: '#3A3A3D',
    borderBottomWidth: 0.5,
  },
  searchContainerLabel: {fontSize: 15, padding: 10},
  inputBoxContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    alignItems: 'center',
    flex: 1,
    justifyContent: 'center',
  },
  inputBox: {flex: 1, marginRight: 2},
  searchResultContainer: {
    height: 50,
    alignItems: 'center',
    flexDirection: 'row',
    paddingLeft: 10,
  },
  searchResultUserImage: {height: 30, width: 30, borderRadius: 5},
  searchResultUserName: {paddingLeft: 10},
  emptyResultIndicator: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  tagContainer: {
    paddingRight: 5,
    flexDirection: 'row',
    margin: 2,
    borderRadius: 3,
  },
  tagImage: {
    height: 25,
    width: 25,
    borderTopLeftRadius: 3,
    borderBottomLeftRadius: 3,
  },
  tagText: {paddingLeft: 10, fontSize: 14, alignSelf: 'center'},
  blurredTagText: {color: '#0080ff'},
});
