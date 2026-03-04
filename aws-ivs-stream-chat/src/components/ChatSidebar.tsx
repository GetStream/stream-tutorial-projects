import { useRef, useState, useEffect } from 'react';
import { useChannelStateContext } from 'stream-chat-react';

const AVATAR_COLORS = [
  '#e91e63', '#9c27b0', '#673ab7', '#3f51b5', '#2196f3',
  '#00bcd4', '#009688', '#4caf50', '#ff9800', '#ff5722',
  '#795548', '#607d8b', '#f44336', '#8bc34a', '#cddc39',
];

function getAvatarColor(name: string): string {
  let hash = 0;
  for (let i = 0; i < name.length; i++) {
    hash = name.charCodeAt(i) + ((hash << 5) - hash);
  }
  return AVATAR_COLORS[Math.abs(hash) % AVATAR_COLORS.length];
}

function formatTime(date: Date | string | undefined): string {
  if (!date) return '';
  const d = typeof date === 'string' ? new Date(date) : date;
  return d.toLocaleTimeString([], {
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  });
}

export default function ChatSidebar() {
  const { messages, channel } = useChannelStateContext();
  const [inputValue, setInputValue] = useState('');
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const handleSend = async () => {
    const text = inputValue.trim();
    if (!text || !channel) return;
    setInputValue('');
    await channel.sendMessage({ text });
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  return (
    <div className="chat-sidebar">
      <div className="chat-messages">
        {messages?.map((msg) => {
          const userName = msg.user?.name || msg.user?.id || 'Unknown';
          return (
            <div key={msg.id} className="chat-message">
              <div
                className="avatar"
                style={{ backgroundColor: getAvatarColor(userName) }}
              >
                {msg.user?.image ? (
                  <img src={msg.user.image} alt="" className="avatar-img" />
                ) : (
                  <span>{userName[0].toUpperCase()}</span>
                )}
              </div>
              <div className="message-body">
                <span className="username">{userName}</span>
                <span className="timestamp">
                  {formatTime(msg.created_at as string | Date | undefined)}
                </span>
                <span className="message-text">{msg.text}</span>
              </div>
            </div>
          );
        })}
        <div ref={messagesEndRef} />
      </div>

      <div className="chat-input-container">
        <input
          type="text"
          className="chat-input"
          placeholder="Type your message"
          value={inputValue}
          onChange={(e) => setInputValue(e.target.value)}
          onKeyDown={handleKeyDown}
        />
        <button
          className="send-btn"
          onClick={handleSend}
          disabled={!inputValue.trim()}
          aria-label="Send message"
        >
          <svg
            width="18"
            height="18"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2.5"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <path d="M12 19V5M5 12l7-7 7 7" />
          </svg>
        </button>
      </div>
    </div>
  );
}
