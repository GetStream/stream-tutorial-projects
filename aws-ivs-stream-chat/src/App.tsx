import { useState, useEffect } from 'react';
import type { Channel as StreamChannel } from 'stream-chat';
import { StreamChat } from 'stream-chat';
import {
  Chat,
  Channel,
  MessageList,
  MessageInput,
  Window,
} from 'stream-chat-react';
import IVSPlayer from './components/IVSPlayer.tsx';

import 'stream-chat-react/dist/css/v2/index.css';
import './App.css';

const apiKey = import.meta.env.VITE_STREAM_API_KEY ?? '';
const userId = import.meta.env.VITE_STREAM_USER_ID ?? '';
const userName = import.meta.env.VITE_STREAM_USER_NAME ?? '';
const userToken = import.meta.env.VITE_STREAM_USER_TOKEN ?? '';
const channelId = import.meta.env.VITE_STREAM_CHANNEL_ID || 'livestream-chat';
const ivsStreamUrl =
  import.meta.env.VITE_IVS_PLAYBACK_URL ||
  'https://fcc3ddae59ed.us-west-2.playback.live-video.net/api/video/v1/us-west-2.893648527354.channel.DmumNckWFTqz.m3u8';

export default function App() {
  const [client, setClient] = useState<StreamChat | null>(null);
  const [channel, setChannel] = useState<StreamChannel | undefined>();
  const [error, setError] = useState<string | null>(null);
  const [chatVisible, setChatVisible] = useState(true);

  useEffect(() => {
    if (!apiKey || !userId || !userToken) {
      setError('Missing Stream Chat credentials in .env file.');
      return;
    }

    const chatClient = new StreamChat(apiKey);

    chatClient
      .connectUser(
        { id: userId, name: userName, image: `https://getstream.io/random_png/?name=${userName}` },
        userToken,
      )
      .then(() => {
        const ch = chatClient.channel('livestream', channelId);
        return ch.watch().then(() => {
          setClient(chatClient);
          setChannel(ch);
        });
      })
      .catch((err) => {
        setError(err instanceof Error ? err.message : String(err));
      });

    return () => {
      chatClient.disconnectUser().catch(() => {});
    };
  }, []);

  if (error) {
    return (
      <div className="app">
        <div className="title-bar">Live Event Chat Demo</div>
        <div className="app-content">
          <div className="player-section">
            <IVSPlayer streamUrl={ivsStreamUrl} />
          </div>
          <div className="chat-panel">
            <div className="status-container">
              <h2 style={{ color: '#ef4444' }}>Chat Connection Error</h2>
              <p style={{ color: '#fca5a5', wordBreak: 'break-word' }}>{error}</p>
            </div>
          </div>
        </div>
      </div>
    );
  }

  if (!client || !channel) {
    return (
      <div className="app">
        <div className="title-bar">Live Event Chat Demo</div>
        <div className="app-content">
          <div className="player-section">
            <IVSPlayer streamUrl={ivsStreamUrl} />
          </div>
          <div className="chat-panel">
            <div className="status-container">
              <div className="loading-spinner" />
              <p>Connecting to chat…</p>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="app">
      <div className="title-bar">Live Event Chat Demo</div>
      <div className="app-content">
        <div className={`player-section ${chatVisible ? '' : 'expanded'}`}>
          <IVSPlayer streamUrl={ivsStreamUrl} />
          <button
            className="toggle-chat-btn"
            onClick={() => setChatVisible((v) => !v)}
          >
            💬 {chatVisible ? 'Hide Chat' : 'Show Chat'}
          </button>
        </div>

        {chatVisible && (
          <div className="chat-panel">
            <Chat client={client} theme="str-chat__theme-dark">
              <Channel channel={channel}>
                <Window>
                  <MessageList />
                  <MessageInput focus />
                </Window>
              </Channel>
            </Chat>
          </div>
        )}
      </div>
    </div>
  );
}
