import React, { useCallback } from "react";
import { Pressable, Text, StyleSheet, View } from "react-native";
import {
  ActivityResponse,
  useFeedsClient,
} from "@stream-io/feeds-react-native-sdk";

type ToggleReactionProps = {
  activity: ActivityResponse;
};

export const Reaction = ({ activity }: ToggleReactionProps) => {
  const client = useFeedsClient();

  const hasReacted = activity.own_reactions?.length > 0;
  const likeCount = activity.reaction_groups?.like?.count ?? 0;

  const toggleReaction = useCallback(() => {
    if (!client) return;

    if (hasReacted) {
      client.deleteActivityReaction({
        activity_id: activity.id,
        type: "like",
      });
    } else {
      client.addActivityReaction({
        activity_id: activity.id,
        type: "like",
      });
    }
  }, [client, activity.id, hasReacted]);

  return (
    <Pressable
      onPress={toggleReaction}
      style={({ pressed }) => [
        styles.button,
        hasReacted && styles.buttonActive,
        pressed && styles.buttonPressed,
      ]}
    >
      <View style={styles.innerRow}>
        <Text style={styles.heart}>{hasReacted ? "❤️" : "🤍"}</Text>
        <Text style={styles.count}>{likeCount}</Text>
      </View>
    </Pressable>
  );
};

const styles = StyleSheet.create({
  button: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 50,
    borderWidth: 1,
    borderColor: "#E5E7EB",
    backgroundColor: "#FFFFFF",
    width: 60,
    alignItems: "center",
    justifyContent: "center",
  },
  buttonActive: {
    backgroundColor: "#2563EB20",
    borderColor: "#2563EB",
  },
  buttonPressed: {
    opacity: 0.7,
  },
  innerRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 4,
  },
  heart: {
    fontSize: 16,
  },
  count: {
    fontSize: 14,
    fontWeight: "600",
    color: "#111827",
    marginLeft: 4,
  },
});
