import React from "react";
import { View, Text, StyleSheet } from "react-native";
import { CommentResponse } from "@stream-io/feeds-client";

type CommentItemProps = {
  comment: CommentResponse;
};

export const Comment = ({ comment }: CommentItemProps) => {
  const name = comment.user?.name || comment.user?.id || "Unknown";
  const initial = name.charAt(0).toUpperCase();

  const createdAtRaw = comment.created_at;
  const createdAt =
    createdAtRaw instanceof Date
      ? createdAtRaw
      : createdAtRaw
        ? new Date(createdAtRaw)
        : null;
  const createdAtLabel = createdAt
    ? createdAt.toLocaleString(undefined, {
        hour: "2-digit",
        minute: "2-digit",
        day: "2-digit",
        month: "short",
      })
    : "";

  return (
    <View style={styles.container}>
      <View style={styles.avatarWrapper}>
        <View style={styles.avatar}>
          <Text style={styles.avatarText}>{initial}</Text>
        </View>
      </View>

      <View style={styles.bubble}>
        <View style={styles.headerRow}>
          <Text style={styles.author} numberOfLines={1}>
            {name}
          </Text>
          {createdAtLabel ? (
            <Text style={styles.timestamp} numberOfLines={1}>
              · {createdAtLabel}
            </Text>
          ) : null}
        </View>

        <Text style={styles.text}>{comment.text}</Text>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    width: "100%",
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    paddingVertical: 6,
    paddingHorizontal: 12,
  },
  avatarWrapper: {
    marginRight: 8,
  },
  avatar: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: "#6366F1",
    alignItems: "center",
    justifyContent: "center",
  },
  avatarText: {
    color: "#FFFFFF",
    fontSize: 16,
    fontWeight: "600",
  },
  bubble: {
    flex: 1,
    borderRadius: 12,
    paddingHorizontal: 10,
    paddingVertical: 8,
    backgroundColor: "#F3F4F6",
  },
  headerRow: {
    flexDirection: "row",
    alignItems: "baseline",
    marginBottom: 2,
    flexWrap: "wrap",
  },
  author: {
    fontWeight: "600",
    fontSize: 14,
    color: "#111827",
    marginRight: 4,
  },
  timestamp: {
    fontSize: 11,
    color: "#6B7280",
  },
  text: {
    fontSize: 14,
    color: "#111827",
    lineHeight: 18,
  },
});
