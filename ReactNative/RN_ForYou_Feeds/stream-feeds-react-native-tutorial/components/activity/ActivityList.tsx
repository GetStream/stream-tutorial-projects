import React, { useCallback } from "react";
import {
  View,
  Text,
  FlatList,
  StyleSheet,
  ActivityIndicator,
} from "react-native";
import type { ActivityResponse } from "@stream-io/feeds-react-native-sdk";
import { useFeedActivities } from "@stream-io/feeds-react-native-sdk";
import { Activity } from "@/components/activity/Activity";

const renderItem = ({ item }: { item: ActivityResponse }) => {
  return <Activity activity={item} />;
};

const keyExtractor = (item: ActivityResponse) => item.id;

const Separator = () => <View style={styles.separator} />;

export const ActivityList = () => {
  const { activities, loadNextPage, has_next_page, is_loading } =
    useFeedActivities();
  const hasActivities = activities?.length && activities.length > 0;

  const ListFooterComponent = useCallback(
    () =>
      is_loading && hasActivities && has_next_page ? (
        <ActivityIndicator />
      ) : null,
    [is_loading, has_next_page, hasActivities],
  );

  if (is_loading && (!activities || activities?.length === 0)) {
    return (
      <View style={styles.emptyContainer}>
        <ActivityIndicator />
      </View>
    );
  }

  if (!activities || activities.length === 0) {
    return (
      <View style={styles.emptyContainer}>
        <Text style={styles.emptyText}>No posts yet</Text>
      </View>
    );
  }

  return (
    <FlatList
      data={activities}
      keyExtractor={keyExtractor}
      renderItem={renderItem}
      contentContainerStyle={styles.listContent}
      onEndReachedThreshold={0.2}
      onEndReached={loadNextPage}
      ItemSeparatorComponent={Separator}
      ListFooterComponent={ListFooterComponent}
    />
  );
};

const styles = StyleSheet.create({
  listContent: {
    flexGrow: 1,
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  separator: {
    height: 12,
  },
  footer: {
    marginTop: 12,
    alignItems: "center",
    justifyContent: "center",
  },
  loadMoreButton: {
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 999,
    backgroundColor: "#2563EB",
  },
  loadMoreButtonPressed: {
    opacity: 0.7,
  },
  loadMoreText: {
    color: "#FFFFFF",
    fontWeight: "600",
    fontSize: 14,
  },
  emptyContainer: {
    flex: 1,
    paddingVertical: 32,
    alignItems: "center",
    justifyContent: "center",
  },
  emptyText: {
    fontSize: 14,
    color: "#6B7280",
  },
});
