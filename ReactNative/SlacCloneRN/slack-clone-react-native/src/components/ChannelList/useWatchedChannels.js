import {useState, useEffect} from 'react';
import {CacheService, ChatClientService} from '../../utils';

export const useWatchedChannels = () => {
  const client = ChatClientService.getClient();
  const [activeChannelId, setActiveChannelId] = useState(null);
  const [unreadChannels, setUnreadChannels] = useState([]);
  const [readChannels, setReadChannels] = useState([]);
  const [directMessagingConversations, setDirectMessagingConversations] =
    useState([]);

  const filters = {
    type: 'messaging',
    example: 'slack-demo',
    members: {
      $in: [client.user.id],
    },
  };

  const sort = {has_unread: -1, last_message_at: -1};
  const options = {limit: 30, offset: 0, state: true};

  useEffect(() => {
    const _unreadChannels = [];
    const _readChannels = [];
    const _directMessagingConversations = [];

    const fetchChannels = async () => {
      const channels = await client.queryChannels(
        {
          ...filters,
          name: {$ne: ''},
        },
        sort,
        options,
      );

      channels.forEach(c => {
        if (c.countUnread() > 0) {
          _unreadChannels.push(c);
        } else {
          _readChannels.push(c);
        }
      });

      setUnreadChannels([..._unreadChannels]);
      setReadChannels([..._readChannels]);
      setDirectMessagingConversations([..._directMessagingConversations]);

      CacheService.setChannels(channels);
    };

    const fetchDirectMessagingConversations = async () => {
      const directMessagingChannels = await client.queryChannels(
        {
          ...filters,
          name: '',
        },
        sort,
        options,
      );

      directMessagingChannels.forEach(c => {
        if (c.countUnread() > 0) {
          _unreadChannels.push(c);
        } else {
          _directMessagingConversations.push(c);
        }
      });

      _unreadChannels.sort((a, b) => {
        return a.state.last_message_at > b.state.last_message_at ? -1 : 1;
      });

      setUnreadChannels([..._unreadChannels]);
      setReadChannels([..._readChannels]);
      setDirectMessagingConversations([..._directMessagingConversations]);

      CacheService.setDirectMessagingConversations(directMessagingChannels);
    };

    async function init() {
      await fetchChannels();
      await fetchDirectMessagingConversations();
      CacheService.loadRecentAndOneToOne();
    }

    init();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    function handleEvents(e) {
      if (e.type === 'message.new') {
        if (e.user?.id === client.user.id) {
          return;
        }
        const cid = e.cid;
        const channelReadIndex = readChannels.findIndex(
          channel => channel.cid === cid,
        );
        if (channelReadIndex >= 0) {
          const channel = readChannels[channelReadIndex];
          readChannels.splice(channelReadIndex, 1);
          setReadChannels([...readChannels]);
          setUnreadChannels([channel, ...unreadChannels]);
        }

        const dmIndex = directMessagingConversations.findIndex(
          channel => channel.cid === cid,
        );
        if (dmIndex >= 0) {
          const channel = directMessagingConversations[dmIndex];
          directMessagingConversations.splice(dmIndex, 1);
          setDirectMessagingConversations([...directMessagingConversations]);
          setUnreadChannels([channel, ...unreadChannels]);
        }

        const channelUnreadIndex = unreadChannels.findIndex(
          channel => channel.cid === cid,
        );
        if (channelUnreadIndex >= 0) {
          const channel = unreadChannels[channelUnreadIndex];
          unreadChannels.splice(channelUnreadIndex, 1);
          setUnreadChannels([channel, ...unreadChannels]);
        }
      }

      if (e.type === 'message.read') {
        if (e.user?.id !== client.user.id) {
          return;
        }
        const cid = e.cid;
        const channelIndex = unreadChannels.findIndex(
          channel => channel.cid === cid,
        );
        if (channelIndex < 0) {
          return;
        }
        const channel = unreadChannels[channelIndex];
        unreadChannels.splice(channelIndex, 1);
        setUnreadChannels([...unreadChannels]);

        if (!channel.data.name) {
          setDirectMessagingConversations([
            channel,
            ...directMessagingConversations,
          ]);
        } else {
          setReadChannels([channel, ...readChannels]);
        }
      }
    }

    client.on(handleEvents);
    return () => {
      client.off(handleEvents);
    };
  }, [client, readChannels, unreadChannels, directMessagingConversations]);

  return {
    activeChannelId,
    setActiveChannelId,
    unreadChannels,
    setUnreadChannels,
    readChannels,
    setReadChannels,
    directMessagingConversations,
    setDirectMessagingConversations,
  };
};
