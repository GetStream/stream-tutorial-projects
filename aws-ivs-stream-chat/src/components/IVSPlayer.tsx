import { useRef, useEffect, useState } from 'react';

interface IVSPlayerProps {
  streamUrl: string;
}

export default function IVSPlayer({ streamUrl }: IVSPlayerProps) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const playerRef = useRef<IVSMediaPlayer | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    setError(null);
    setIsLoading(true);

    const IVSPlayerSDK = window.IVSPlayer;

    if (!IVSPlayerSDK) {
      setError('IVS Player SDK not loaded');
      setIsLoading(false);
      return;
    }

    if (!IVSPlayerSDK.isPlayerSupported) {
      setError('IVS Player is not supported in this browser');
      setIsLoading(false);
      return;
    }

    if (!videoRef.current) return;

    let isActive = true;
    const player = IVSPlayerSDK.create();
    playerRef.current = player;

    player.attachHTMLVideoElement(videoRef.current);
    player.setAutoplay(true);

    const onStateChange = (state: unknown) => {
      if (!isActive) return;
      if (state === IVSPlayerSDK.PlayerState.PLAYING) {
        setIsLoading(false);
        setError(null);
      }
    };

    const onError = (err: unknown) => {
      if (!isActive) return;
      console.error('IVS Player Error:', err);
      setError('Stream unavailable — the channel may be offline');
      setIsLoading(false);
    };

    player.addEventListener(IVSPlayerSDK.PlayerEventType.STATE_CHANGED, onStateChange);
    player.addEventListener(IVSPlayerSDK.PlayerEventType.ERROR, onError);

    player.load(streamUrl);

    return () => {
      isActive = false;
      player.removeEventListener(IVSPlayerSDK.PlayerEventType.STATE_CHANGED, onStateChange);
      player.removeEventListener(IVSPlayerSDK.PlayerEventType.ERROR, onError);
      player.delete();
      playerRef.current = null;
    };
  }, [streamUrl]);

  return (
    <div className="ivs-player">
      {isLoading && !error && (
        <div className="player-overlay">
          <div className="loading-spinner" />
          <p>Loading stream…</p>
        </div>
      )}
      {error && (
        <div className="player-overlay">
          <p className="error-text">{error}</p>
          <p className="error-hint">
            Configure a valid IVS playback URL in your .env file
          </p>
        </div>
      )}
      <video ref={videoRef} playsInline />
    </div>
  );
}
