import React from "react";
import { View, StyleSheet } from "react-native";
import { StreamFeed } from "@stream-io/feeds-react-native-sdk";
import { useOwnFeedsContext } from "@/contexts/own-feeds-context";
import { ActivityList } from "@/components/activity/ActivityList";
import { ActivityComposer } from "@/components/activity/ActivityComposer";

export default function HomeScreen() {
  const { ownTimeline, ownFeed } = useOwnFeedsContext();

  if (!ownTimeline || !ownFeed) {
    return null;
  }

  return (
    <View style={styles.container}>
      <StreamFeed feed={ownFeed}>
        <ActivityComposer />
      </StreamFeed>
      <StreamFeed feed={ownTimeline}>
        <ActivityList />
      </StreamFeed>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: "stretch",
    justifyContent: "flex-start",
  },
});
