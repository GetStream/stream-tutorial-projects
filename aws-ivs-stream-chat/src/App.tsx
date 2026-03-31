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
import IVSRealTime from './components/IVSRealTime.tsx';

import 'stream-chat-react/dist/css/v2/index.css';
import './App.css';

type StreamingMode = 'low-latency' | 'real-time';

const apiKey = import.meta.env.VITE_STREAM_API_KEY ?? '';
const userId = import.meta.env.VITE_STREAM_USER_ID ?? '';
const userName = import.meta.env.VITE_STREAM_USER_NAME ?? '';
const userToken = import.meta.env.VITE_STREAM_USER_TOKEN ?? '';
const channelId = import.meta.env.VITE_STREAM_CHANNEL_ID || 'livestream-chat';
const ivsStreamUrl =
  import.meta.env.VITE_IVS_PLAYBACK_URL ||
  'https://fcc3ddae59ed.us-west-2.playback.live-video.net/api/video/v1/us-west-2.893648527354.channel.DmumNckWFTqz.m3u8';
const ivsStageToken = import.meta.env.VITE_IVS_STAGE_TOKEN ?? '';

export default function App() {
  const [client, setClient] = useState<StreamChat | null>(null);
  const [channel, setChannel] = useState<StreamChannel | undefined>();
  const [error, setError] = useState<string | null>(null);
  const [chatVisible, setChatVisible] = useState(true);
  const [streamingMode, setStreamingMode] = useState<StreamingMode>('low-latency');

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

  const renderVideoSection = () => {
    if (streamingMode === 'real-time') {
      return <IVSRealTime token={ivsStageToken} />;
    }
    return <IVSPlayer streamUrl={ivsStreamUrl} />;
  };

  const modeToggle = (
    <div className="mode-toggle">
      <button
        className={`mode-toggle-btn ${streamingMode === 'low-latency' ? 'active' : ''}`}
        onClick={() => setStreamingMode('low-latency')}
      >
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <polygon points="5 3 19 12 5 21 5 3" />
        </svg>
        Low-Latency
      </button>
      <button
        className={`mode-toggle-btn ${streamingMode === 'real-time' ? 'active' : ''}`}
        onClick={() => setStreamingMode('real-time')}
      >
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
          <circle cx="9" cy="7" r="4" />
          <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
          <path d="M16 3.13a4 4 0 0 1 0 7.75" />
        </svg>
        Real-Time
      </button>
    </div>
  );

  if (error) {
    return (
      <div className="app">
        <div className="title-bar">
          <span className="title-text">Live Event Chat Demo</span>
          {modeToggle}
        </div>
        <div className="app-content">
          <div className="player-section">
            {renderVideoSection()}
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
        <div className="title-bar">
          <span className="title-text">Live Event Chat Demo</span>
          {modeToggle}
        </div>
        <div className="app-content">
          <div className="player-section">
            {renderVideoSection()}
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
      <div className="title-bar">
        <span className="title-text">Live Event Chat Demo</span>
        {modeToggle}
      </div>
      <div className="app-content">
        <div className={`player-section ${chatVisible ? '' : 'expanded'}`}>
          {renderVideoSection()}
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
