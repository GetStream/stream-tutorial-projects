/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_STREAM_API_KEY: string;
  readonly VITE_STREAM_USER_TOKEN: string;
  readonly VITE_STREAM_USER_ID: string;
  readonly VITE_STREAM_USER_NAME: string;
  readonly VITE_STREAM_CHANNEL_ID: string;
  readonly VITE_IVS_PLAYBACK_URL: string;
  readonly VITE_IVS_STAGE_TOKEN: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
