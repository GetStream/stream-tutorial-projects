import { useLocalSearchParams } from "expo-router";
import { StyleSheet } from "react-native";
import { useEffect, useState } from "react";
import {
  ActivityWithStateUpdates,
  useFeedsClient,
} from "@stream-io/feeds-react-native-sdk";
import { CommentList } from "@/components/comments/CommentList";
import { CommentComposer } from "@/components/comments/CommentComposer";
import { SafeAreaView } from "react-native-safe-area-context";

export default function CommentsModal() {
  const client = useFeedsClient();
  const { activityId: activityIdParam } = useLocalSearchParams();
  const [activityWithStateUpdates, setActivityWithStateUpdates] = useState<
    ActivityWithStateUpdates | undefined
  >(undefined);

  const activityId = activityIdParam as string;

  useEffect(() => {
    const activity = client?.activityWithStateUpdates(activityId);

    if (!activity) {
      return;
    }

    if (typeof activity.currentState.activity?.comments === "undefined") {
      activity.get().then(() => setActivityWithStateUpdates(activity));
    }

    return () => {
      activity?.dispose();
    };
  }, [client, activityId]);

  if (!activityWithStateUpdates) {
    return null;
  }

  return (
    <SafeAreaView style={styles.safeArea}>
      <CommentList activity={activityWithStateUpdates} />
      <CommentComposer activity={activityWithStateUpdates} />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: { flex: 1, backgroundColor: "white" },
  container: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    padding: 20,
  },
  link: {
    marginTop: 15,
    paddingVertical: 15,
  },
});
