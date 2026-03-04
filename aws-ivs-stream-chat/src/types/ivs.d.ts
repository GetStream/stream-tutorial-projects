declare global {
  interface IVSPlayerStatic {
    isPlayerSupported: boolean;
    create(): IVSMediaPlayer;
    PlayerState: {
      IDLE: string;
      READY: string;
      BUFFERING: string;
      PLAYING: string;
      ENDED: string;
    };
    PlayerEventType: {
      STATE_CHANGED: string;
      ERROR: string;
      QUALITY_CHANGED: string;
      DURATION_CHANGED: string;
      REBUFFERING: string;
      TEXT_CUE: string;
      TEXT_METADATA_CUE: string;
      NETWORK_UNAVAILABLE: string;
    };
  }

  interface IVSMediaPlayer {
    attachHTMLVideoElement(videoElement: HTMLVideoElement): void;
    load(url: string): void;
    play(): void;
    pause(): void;
    delete(): void;
    setAutoplay(autoplay: boolean): void;
    setVolume(volume: number): void;
    getVolume(): number;
    setMuted(muted: boolean): void;
    isMuted(): boolean;
    getState(): string;
    addEventListener(event: string, callback: (data?: unknown) => void): void;
    removeEventListener(event: string, callback: (data?: unknown) => void): void;
    setQuality(quality: unknown, adaptive?: boolean): void;
    getQualities(): unknown[];
  }

  interface Window {
    IVSPlayer: IVSPlayerStatic;
  }
}

export {};
