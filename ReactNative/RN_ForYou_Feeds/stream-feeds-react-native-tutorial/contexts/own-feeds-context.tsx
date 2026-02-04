import {
  Feed,
  useClientConnectedUser,
  useFeedsClient,
} from "@stream-io/feeds-react-native-sdk";

import {
  createContext,
  PropsWithChildren,
  useContext,
  useEffect,
  useState,
} from "react";

type OwnFeedsContextValue = {
  ownFeed: Feed | undefined;
  ownTimeline: Feed | undefined;
};

const OwnFeedsContext = createContext<OwnFeedsContextValue>({
  ownFeed: undefined,
  ownTimeline: undefined,
});

export const OwnFeedsContextProvider = ({ children }: PropsWithChildren) => {
  const [ownFeed, setOwnFeed] = useState<Feed>();
  const [ownTimeline, setOwnTimeline] = useState<Feed>();
  const client = useFeedsClient();
  const connectedUser = useClientConnectedUser();

  useEffect(() => {
    if (!connectedUser || !client) return;

    const feed = client.feed("user", connectedUser.id);

    setOwnFeed(feed);

    // Social media apps usually don't add new activities from WebSocket
    // users need to pull to refresh
    const timeline = client.feed("timeline", connectedUser.id, {
      activityAddedEventFilter: ({ activity }) =>
        activity.user?.id === connectedUser.id,
    });

    setOwnTimeline(timeline);

    Promise.all([
      feed.getOrCreate({ watch: true }),
      timeline.getOrCreate({ watch: true }),
    ]).then(() => {
      // You typically create these relationships on your server-side, we do this here for simplicity
      const alreadyFollows = feed.currentState.own_follows?.find(
        (follow) => follow.source_feed.feed === timeline.feed,
      );
      if (!alreadyFollows) timeline.follow(feed);
    });

    return () => {
      setOwnFeed(undefined);
      setOwnTimeline(undefined);
    };
  }, [connectedUser, client]);

  return (
    <OwnFeedsContext.Provider value={{ ownFeed, ownTimeline }}>
      {children}
    </OwnFeedsContext.Provider>
  );
};

export const useOwnFeedsContext = () => useContext(OwnFeedsContext);
