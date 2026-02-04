import React, { useCallback, useMemo } from "react";
import { Pressable, Text, StyleSheet } from "react-native";
import { useOwnFeedsContext } from "@/contexts/own-feeds-context";
import {
  FeedResponse,
  FollowResponse,
  useFeedsClient,
  useOwnFollows,
} from "@stream-io/feeds-react-native-sdk";

export const FollowButton = ({
  feed: activityFeed,
}: {
  feed?: FeedResponse;
}) => {
  const client = useFeedsClient();
  const feed = useMemo(() => {
    if (!activityFeed) return;

    return client?.feed(activityFeed.group_id, activityFeed.id);
  }, [client, activityFeed]);
  const { ownTimeline } = useOwnFeedsContext();

  const { own_follows: ownFollows } =
    useOwnFollows(feed) ?? {};
  const ownFollow = useMemo(
    () =>
      ownFollows &&
      ownFollows.find(
        (follow: FollowResponse) => follow.source_feed.group_id === "timeline",
      ),
    [ownFollows],
  );
  const isFollowing = ownFollow?.status === "accepted";

  const follow = useCallback(async () => {
    await ownTimeline?.follow(feed!.feed);

    // Reload to pull new activities
    await ownTimeline?.getOrCreate({ watch: true });
  }, [feed, ownTimeline]);

  const unfollow = useCallback(async () => {
    await ownTimeline?.unfollow(feed!.feed);

    // Reload to remove activities
    await ownTimeline?.getOrCreate({ watch: true });
  }, [feed, ownTimeline]);

  const toggleFollow = useCallback(() => {
    if (isFollowing) unfollow();
    else follow();
  }, [isFollowing, follow, unfollow]);

  return (
    <Pressable
      onPress={toggleFollow}
      style={({ pressed }) => [
        styles.button,
        isFollowing ? styles.unfollow : styles.follow,
        pressed && styles.pressed,
      ]}
    >
      <Text style={styles.buttonText}>
        {isFollowing ? "Unfollow" : "Follow"}
      </Text>
    </Pressable>
  );
};

const styles = StyleSheet.create({
  button: {
    paddingHorizontal: 14,
    paddingVertical: 6,
    borderRadius: 8,
    alignItems: "center",
    justifyContent: "center",
    minWidth: 80,
  },
  follow: {
    backgroundColor: "#2563EB",
  },
  unfollow: {
    backgroundColor: "#DC2626",
  },
  pressed: {
    opacity: 0.8,
  },
  buttonText: {
    color: "white",
    fontWeight: "600",
    fontSize: 14,
  },
});
