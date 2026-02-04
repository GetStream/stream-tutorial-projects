import React, { useCallback } from "react";
import { View, FlatList, StyleSheet, ActivityIndicator } from "react-native";
import {
  ActivityWithStateUpdates,
  useActivityComments,
  CommentResponse,
} from "@stream-io/feeds-react-native-sdk";

import { Comment } from "@/components/comments/Comment";

type CommentListProps = {
  activity: ActivityWithStateUpdates;
};

const renderItem = ({ item }: { item: CommentResponse }) => (
  <Comment comment={item} />
);

const keyExtractor = (item: CommentResponse) => item.id;

const maintainVisibleContentPosition = {
  minIndexForVisible: 0,
  autoscrollToTopThreshold: 10,
};

export const CommentList = ({ activity }: CommentListProps) => {
  const {
    comments = [],
    loadNextPage: loadNextCommentsPage,
    has_next_page,
    is_loading_next_page,
  } = useActivityComments({ activity });

  const loadNextPage = useCallback(() => {
    if (!loadNextCommentsPage || !has_next_page || is_loading_next_page) {
      return;
    }

    loadNextCommentsPage({
      limit: 10,
      sort: "last",
    });
  }, [loadNextCommentsPage, has_next_page, is_loading_next_page]);

  return (
    <View style={styles.container}>
      <FlatList
        data={comments}
        keyExtractor={keyExtractor}
        renderItem={renderItem}
        contentContainerStyle={styles.listContent}
        maintainVisibleContentPosition={maintainVisibleContentPosition}
        onEndReachedThreshold={0.2}
        onEndReached={loadNextPage}
        ListFooterComponent={
          is_loading_next_page && has_next_page ? ActivityIndicator : null
        }
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    width: "100%",
    flex: 1,
    marginTop: 8,
  },
  listContent: {
    flexGrow: 1,
    paddingBottom: 4,
  },
  loadMoreButton: {
    marginTop: 8,
    alignSelf: "flex-start",
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 999,
    backgroundColor: "#2563EB20",
  },
  loadMoreButtonPressed: {
    opacity: 0.8,
  },
  loadMoreText: {
    color: "#2563EB",
    fontWeight: "600",
    fontSize: 13,
  },
});
