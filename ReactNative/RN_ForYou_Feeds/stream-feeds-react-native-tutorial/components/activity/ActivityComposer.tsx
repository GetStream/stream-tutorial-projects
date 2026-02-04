import React, { useCallback, useState } from "react";
import {
  View,
  Text,
  TextInput,
  StyleSheet,
  Pressable,
  Platform,
} from "react-native";
import {
  ImageUploadResponse,
  StreamResponse,
  useFeedContext,
} from "@stream-io/feeds-react-native-sdk";
import { ImagePicker } from "@/components/activity/ImagePicker";
import Animated, {
  LinearTransition,
  ZoomIn,
  ZoomOut,
} from "react-native-reanimated";

export const ActivityComposer = () => {
  const feed = useFeedContext();
  const [newText, setNewText] = useState("");
  const [image, setImage] = useState<
    StreamResponse<ImageUploadResponse> | undefined
  >(undefined);

  const canPost = newText.trim().length > 0;

  const sendActivity = useCallback(async () => {
    if (!feed || !canPost) return;

    await feed.addActivity({
      text: newText,
      type: "post",
      ...(image
        ? {
            attachments: [{ type: "image", image_url: image.file, custom: {} }],
          }
        : null),
    });

    setNewText("");
    setImage(undefined);
  }, [feed, newText, canPost, image]);

  return (
    <View style={styles.card}>
      <View style={styles.inner}>
        <TextInput
          style={styles.input}
          multiline
          placeholder="What is happening?"
          value={newText}
          onChangeText={setNewText}
          textAlignVertical="top"
          underlineColorAndroid="transparent"
          placeholderTextColor="#9CA3AF"
        />
        {image ? (
          <View>
            <Animated.Image
              style={styles.imagePreview}
              entering={ZoomIn.duration(150)}
              exiting={ZoomOut.duration(150)}
              source={{ uri: image?.file }}
            />
            <Pressable
              onPress={() => setImage(undefined)}
              style={styles.removeButton}
            >
              <Text style={styles.removeButtonText}>X</Text>
            </Pressable>
          </View>
        ) : null}
        <Animated.View layout={LinearTransition.duration(200)}>
          <View style={styles.footerRow}>
            {image ? <View /> : <ImagePicker onUpload={setImage} />}
            <Pressable
              onPress={sendActivity}
              disabled={!canPost}
              style={({ pressed }) => [
                styles.button,
                !canPost && styles.buttonDisabled,
                pressed && canPost && styles.buttonPressed,
              ]}
            >
              <Text style={styles.buttonText}>Post</Text>
            </Pressable>
          </View>
        </Animated.View>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  card: {
    padding: 12,
    borderRadius: 12,
    marginHorizontal: 16,
    marginTop: 8,
    backgroundColor: "#FFFFFF",
    borderWidth: 1,
    borderColor: "#E5E7EB",
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 3,
    elevation: 2,
  },
  inner: {
    width: "100%",
    flexDirection: "column",
    gap: 8,
  },
  input: {
    minHeight: 80,
    maxHeight: 160,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: "#E5E7EB",
    paddingHorizontal: 12,
    paddingVertical: Platform.OS === "ios" ? 10 : 8,
    fontSize: 14,
    color: "#111827",
  },
  footerRow: {
    width: "100%",
    marginTop: 8,
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
  },
  button: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 999,
    backgroundColor: "#2563EB",
  },
  buttonPressed: {
    opacity: 0.8,
  },
  buttonDisabled: {
    backgroundColor: "#93C5FD",
  },
  buttonText: {
    color: "#FFFFFF",
    fontWeight: "600",
    fontSize: 14,
  },
  imagePreview: {
    width: "100%",
    resizeMode: "cover",
    height: 100,
    paddingHorizontal: 16,
    borderRadius: 16,
  },
  removeButtonText: { color: "white" },
  removeButton: {
    position: "absolute",
    top: 4,
    right: 20,
    backgroundColor: "rgba(0,0,0,0.6)",
    borderRadius: 999,
    padding: 2,
    width: 24,
    height: 24,
    alignItems: "center",
    justifyContent: "center",
  },
});
