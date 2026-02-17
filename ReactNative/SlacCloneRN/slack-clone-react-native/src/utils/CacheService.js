import ChatClientService from './ChatClientService';

let _channels = [];
let _directMessagingConversations = [];
let _oneToOneConversations = [];
let _recentConversations = [];
let _members = [];

const CacheService = {
  getChannels: () => _channels,
  getDirectMessagingConversations: () => _directMessagingConversations,
  getOneToOneConversations: () => _oneToOneConversations,
  getRecentConversations: () => _recentConversations,
  getMembers: () => _members,

  setDirectMessagingConversations: conversations => {
    _directMessagingConversations = conversations;
  },

  setChannels: channels => {
    _channels = channels;
  },

  loadRecentAndOneToOne: () => {
    const chatClient = ChatClientService.getClient();
    const memberIds = [];

    _oneToOneConversations = _directMessagingConversations.filter(c => {
      const memberLength = Object.keys(c.state.members).length;
      if (memberLength === 2) {
        const otherMember = Object.values(c.state.members).find(
          m => m.user.id !== chatClient.user.id,
        );

        if (memberIds.indexOf(otherMember.user.id) === -1) {
          memberIds.push(otherMember.user.id);
          _members.push({...otherMember.user, channelId: c.id});
        }
        return true;
      }
      return false;
    });

    _recentConversations = [..._channels, ..._directMessagingConversations];
    _recentConversations.sort((a, b) => {
      return a.state.last_message_at > b.state.last_message_at ? -1 : 1;
    });
  },
};

export default CacheService;
