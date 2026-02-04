import React, { useCallback, useState } from "react";
import { Pressable, Text, StyleSheet, ActivityIndicator } from "react-native";
import * as ExpoImagePicker from "expo-image-picker";
import {
  ImageUploadResponse,
  StreamResponse,
  useFeedsClient,
} from "@stream-io/feeds-react-native-sdk";
import Animated, { FadeIn, FadeOut } from "react-native-reanimated";

type PhotoButtonProps = {
  onUpload: (
    uploadedImage: StreamResponse<ImageUploadResponse> | undefined,
  ) => void;
};

export const ImagePicker = ({ onUpload }: PhotoButtonProps) => {
  const client = useFeedsClient();
  const [isUploading, setIsUploading] = useState<boolean>(false);

  const pickImage = useCallback(async () => {
    const result = await ExpoImagePicker.launchImageLibraryAsync({
      mediaTypes: "images",
      allowsMultipleSelection: false,
      quality: 1,
    });

    if (!result.canceled) {
      const asset = result.assets[0];

      const file = {
        uri: asset.uri,
        name: asset.fileName ?? (asset.uri as string).split("/").reverse()[0],
        duration: asset.duration,
        type: asset.mimeType ?? "image/jpeg",
      };

      setIsUploading(true);
      const uploadedFile = await client?.uploadImage({
        file,
      });
      setIsUploading(false);

      onUpload(uploadedFile);
    }
  }, [client, onUpload]);

  return (
    <Animated.View
      entering={FadeIn.duration(150)}
      exiting={FadeOut.duration(150)}
    >
      <Pressable
        onPress={pickImage}
        disabled={isUploading}
        style={({ pressed }) => [
          styles.button,
          pressed && !isUploading && styles.buttonPressed,
          isUploading && styles.buttonDisabled,
        ]}
      >
        {isUploading ? (
          <ActivityIndicator size="small" />
        ) : (
          <Text style={styles.text}>📎</Text>
        )}
      </Pressable>
    </Animated.View>
  );
};

const styles = StyleSheet.create({
  button: {
    alignItems: "center",
    justifyContent: "center",
    minHeight: 36,
    alignSelf: "flex-start",
  },
  buttonPressed: {
    opacity: 0.8,
  },
  buttonDisabled: {
    opacity: 0.7,
  },
  content: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    minWidth: 60,
  },
  text: {
    color: "#FFFFFF",
    fontWeight: "600",
    fontSize: 30,
  },
});
