import React, { useState, useCallback } from "react";
import {
  TextInput,
  Pressable,
  Text,
  StyleSheet,
  Platform,
  KeyboardAvoidingView,
} from "react-native";
import {
  ActivityWithStateUpdates,
  useFeedsClient,
} from "@stream-io/feeds-react-native-sdk";

type CommentComposerProps = {
  activity: ActivityWithStateUpdates;
};

export const CommentComposer = ({ activity }: CommentComposerProps) => {
  const client = useFeedsClient();
  const [commentDraft, setCommentDraft] = useState("");

  const canReply = commentDraft.trim().length > 0;

  const addComment = useCallback(async () => {
    if (!client || !canReply) return;

    await client.addComment({
      object_id: activity.id,
      object_type: "activity",
      comment: commentDraft,
    });

    setCommentDraft("");
  }, [client, activity.id, commentDraft, canReply]);

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === "ios" ? "padding" : undefined}
      keyboardVerticalOffset={Platform.OS === "ios" ? 128 : 0}
    >
      <TextInput
        style={styles.input}
        placeholder="Post your reply"
        value={commentDraft}
        onChangeText={setCommentDraft}
        placeholderTextColor="#9CA3AF"
        autoCapitalize="sentences"
        autoCorrect
        returnKeyType="send"
        onSubmitEditing={addComment}
      />
      <Pressable
        onPress={addComment}
        disabled={!canReply}
        style={({ pressed }) => [
          styles.button,
          !canReply && styles.buttonDisabled,
          pressed && canReply && styles.buttonPressed,
        ]}
      >
        <Text style={styles.buttonText}>Reply</Text>
      </Pressable>
    </KeyboardAvoidingView>
  );
};

const styles = StyleSheet.create({
  container: {
    width: "100%",
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
    marginTop: 8,
    paddingHorizontal: 12,
  },
  input: {
    flex: 1,
    borderRadius: 999,
    borderWidth: 1,
    borderColor: "#E5E7EB",
    paddingHorizontal: 14,
    paddingVertical: Platform.OS === "ios" ? 10 : 8,
    fontSize: 14,
    color: "#111827",
    backgroundColor: "#FFFFFF",
  },
  button: {
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 999,
    backgroundColor: "#2563EB",
    alignItems: "center",
    justifyContent: "center",
    minWidth: 70,
  },
  buttonDisabled: {
    backgroundColor: "#93C5FD",
  },
  buttonPressed: {
    opacity: 0.8,
  },
  buttonText: {
    color: "#FFFFFF",
    fontWeight: "600",
    fontSize: 14,
  },
});
