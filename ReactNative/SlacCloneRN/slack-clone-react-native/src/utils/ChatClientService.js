let _client = null;

const ChatClientService = {
  setClient: client => {
    _client = client;
  },
  getClient: () => _client,
};

export default ChatClientService;
