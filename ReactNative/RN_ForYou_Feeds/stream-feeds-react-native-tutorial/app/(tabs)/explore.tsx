import {
  useFeedsClient,
  useClientConnectedUser,
  StreamFeed,
} from "@stream-io/feeds-react-native-sdk";
import { useEffect, useMemo } from "react";
import { ActivityList } from "@/components/activity/ActivityList";

export default function ExploreScreen() {
  const client = useFeedsClient();
  const currentUser = useClientConnectedUser();
  const feed = useMemo(() => {
    if (!currentUser?.id || !client) {
      return undefined;
    }
    return client.feed("foryou", currentUser.id);
  }, [client, currentUser?.id]);

  useEffect(() => {
    if (feed) {
      feed.getOrCreate({ limit: 10 });
    }
  }, [feed]);

  if (!feed) {
    return null;
  }

  return (
    <StreamFeed feed={feed}>
      <ActivityList />
    </StreamFeed>
  );
}
