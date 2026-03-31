# Live Event Chat Demo — AWS IVS + Stream Chat React

A real-time live streaming service that combines **Amazon IVS** for video (both Low-Latency and Real-Time modes) with **Stream Chat React** for interactive messaging, reactions, and comments. Viewers can toggle between **IVS Low-Latency** playback and **IVS Real-Time** stage participation without leaving the page.

![Live Event Chat Demo](https://github.com/user-attachments/assets/preview.gif)

---

## Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Step 1 — Set Up Amazon IVS](#step-1--set-up-amazon-ivs)
5. [Step 2 — Set Up Stream Chat](#step-2--set-up-stream-chat)
6. [Step 3 — Configure & Run the Project](#step-3--configure--run-the-project)
7. [Project Structure](#project-structure)
8. [How It Works](#how-it-works)
9. [Customization](#customization)
10. [Troubleshooting](#troubleshooting)
11. [Where To Go From Here](#resources)

---

## Overview

This demo app shows how to build a Twitch-style live streaming experience where:

- **Video** is delivered through Amazon Interactive Video Service (IVS) with two modes:
  - **Low-Latency** — Traditional HLS playback with sub-second latency, ideal for large audiences watching a broadcast.
  - **Real-Time** — WebRTC-based stage participation using the IVS Real-Time Broadcast SDK, enabling multi-party interactive video with ultra-low latency (~300 ms).
- **Messaging** is powered by Stream Chat React, providing real-time chatting with typing indicators, message status indicators (sending, received), user role configuration, emoji support (opt-in), message read indicators, threading, message replies, reactions, URL previews (send a YouTube link to see this in action), file uploads and previews, and video playback.
- A **Streaming Mode Toggle** in the title bar lets users switch between Low-Latency and Real-Time modes.
- A **Messages UI** places the chat next to the live player, with a toggle button to show/hide the chat panel.

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                       React App (Vite)                           │
│                                                                  │
│  ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐  │
│  │  IVS Player SDK  │ │  IVS Real-Time   │ │  Stream Chat     │  │
│  │  (CDN script)    │ │  Broadcast SDK   │ │  React SDK       │  │
│  │                  │ │  (npm package)   │ │  (npm package)   │  │
│  │  HLS playback    │ │  WebRTC stage    │ │  WebSocket chat  │  │
│  └────────┬─────────┘ └────────┬─────────┘ └────────┬─────────┘  │
│           │                    │                     │            │
└───────────┼────────────────────┼─────────────────────┼────────────┘
            │                    │                     │
            ▼                    ▼                     ▼
   Amazon IVS Channel    Amazon IVS Stage      Stream Chat Backend
   (video ingest +       (real-time WebRTC     (message storage,
    low-latency HLS)      multi-party video)    real-time delivery)
```

**Low-Latency mode** — You stream to an IVS ingest endpoint (with OBS, FFmpeg, etc.) and viewers receive near-real-time HLS playback through the IVS Player SDK loaded from CDN.

**Real-Time mode** — Participants connect to an IVS Stage via WebRTC using the IVS Real-Time Broadcast SDK (`amazon-ivs-web-broadcast` npm package). Each participant shares their camera and microphone and receives streams from other participants with ultra-low latency.

**Stream Chat** handles the messaging pipeline — users connect via WebSocket, send messages, and receive updates in real time. The React SDK provides hooks and components for building custom chat UIs.

---

## Prerequisites

Before you begin, make sure you have:

| Requirement | Details |
|---|---|
| **Node.js** | v18 or later ([download](https://nodejs.org)) |
| **npm or Yarn** | Comes with Node.js |
| **AWS account** | [Sign up](https://aws.amazon.com/) — IVS is available in the free tier |
| **Stream account** | [Sign up](https://getstream.io/try-for-free/) — free Maker plan available |
| **A streaming tool** | [OBS Studio](https://obsproject.com/), FFmpeg, or any RTMP-capable software (for Low-Latency mode) |
| **HTTPS** | Required for Real-Time mode (camera/microphone access). `localhost` works for development. |

---

## Step 1 — Set Up Amazon IVS

### Low-Latency Channel (HLS Playback)

Amazon IVS provides managed, low-latency live streaming infrastructure. Follow these steps to create a channel and get a playback URL.

#### 1.1 Create an IVS Channel

1. Sign in to the [AWS Management Console](https://console.aws.amazon.com/).
2. Navigate to **Amazon IVS** (search for "IVS" in the services search bar).
3. In the left sidebar, select **Channels** under the *Low-latency streaming* section.
4. Click **Create channel**.
5. Configure the channel:
   - **Channel name**: `live-event-demo` (or any name you prefer)
   - **Latency mode**: *Low-latency* (recommended for interactive use cases)
   - **Type**: *Standard* (sufficient for most demos)
   - **Recording**: Leave off unless you want VOD replays
6. Click **Create channel**.

#### 1.2 Copy the Playback URL

After creating the channel:

1. Open the channel details page.
2. Under **Playback configuration**, find the **Playback URL** — it looks like:
   ```
   https://abc123def456.us-west-2.playback.live-video.net/api/video/v1/us-west-2.123456789012.channel.AbCdEfGhIjKl.m3u8
   ```
3. Copy this URL — you will add it to your `.env` file in Step 3.

#### 1.3 Copy the Ingest Configuration

To start streaming, you also need:

- **Ingest server**: `rtmps://abc123def456.global-contribute.live-video.net:443/app/`
- **Stream key**: Shown on the channel details page (click **Show** to reveal it)

Use these in OBS Studio or your preferred streaming tool.

#### 1.4 Start a Test Stream (Optional)

To see the video player working without setting up OBS:

- AWS provides a **test stream** you can use as the playback URL:
  ```
  https://fcc3ddae59ed.us-west-2.playback.live-video.net/api/video/v1/us-west-2.893648527354.channel.DmumNckWFTqz.m3u8
  ```
  This is a publicly available IVS demo stream. The app uses this URL by default if you don't provide one.

> **Learn more**: [Getting Started with Amazon IVS](https://docs.aws.amazon.com/ivs/latest/LowLatencyUserGuide/getting-started.html)

### Real-Time Stage (WebRTC)

IVS Real-Time lets multiple participants share audio and video with ultra-low latency (~300 ms). Follow these steps to create a stage and generate a participant token.

#### 1.5 Create an IVS Stage

1. In the AWS Console, navigate to **Amazon IVS**.
2. In the left sidebar, select **Stages** under the *Real-time streaming* section.
3. Click **Create stage**.
4. Give the stage a name (e.g., `live-event-stage`).
5. Click **Create stage**.

#### 1.6 Create a Participant Token

Each participant needs a token to join the stage. You can create tokens via the AWS Console or the `CreateParticipantToken` API.

**Via the Console:**

1. Open your stage's detail page.
2. Under **Participant tokens**, click **Create a participant token**.
3. Set a **User ID** (e.g., `host-user`) and optional attributes.
4. Copy the generated token — you will add it to your `.env` file as `VITE_IVS_STAGE_TOKEN`.

**Via the AWS CLI:**

```bash
aws ivs-realtime create-participant-token \
  --stage-arn arn:aws:ivs:us-west-2:123456789012:stage/AbCdEfGhIjKl \
  --user-id host-user \
  --capabilities '["PUBLISH","SUBSCRIBE"]'
```

> **Note**: Participant tokens are short-lived. For production, generate them on a backend server using the AWS SDK.

> **Learn more**: [Getting Started with IVS Real-Time Streaming](https://docs.aws.amazon.com/ivs/latest/RealTimeUserGuide/getting-started-introduction.html) | [IVS Real-Time Broadcast SDK — Web](https://docs.aws.amazon.com/ivs/latest/RealTimeUserGuide/broadcast-web.html)

---

## Step 2 — Set Up Stream Chat

Stream Chat provides the real-time messaging backend. You need an API key, a user, and a token.

### 2.1 Create a Stream Application

1. Go to the [Stream Dashboard](https://dashboard.getstream.io/).
2. Click **Create App**.
3. Fill in:
   - **App name**: `live-event-chat` (or any name)
   - **Environment**: *Development*
4. Click **Create App**.

### 2.2 Get Your API Key and Secret

1. Open your newly created app from the dashboard.
2. In **App Settings** → **General**, find:
   - **API Key** (public — safe for the frontend)
   - **API Secret** (private — keep this on the server side only; used to generate tokens)
3. Copy the **API Key** — you will add it to your `.env` file.

### 2.3 Create a User and Generate a Token

Stream Chat uses JWT tokens for authentication. For development, you can generate a token using the Stream CLI or the dashboard.

#### Option A: Using the Stream Dashboard

1. In your app dashboard, navigate to **Explorer** → **Users**.
2. Click **Create User**.
3. Set a **User ID** (e.g., `demo-user`) and an optional **Name**.
4. After creating the user, use the **Token Generator** tool in the dashboard (or the Dev Token option below).

#### Option B: Using a Dev Token (Quickest for Development)

For development, you can enable **Disable Auth Checks** in the dashboard:

1. Go to **App Settings** → **General**.
2. Toggle **Disable Auth Checks** to *ON*.
3. Use the user ID as the token value (no JWT needed).

> **Warning**: Only use this for local development. Always use proper JWT tokens in production.

#### Option C: Generate a Token with Node.js

Create a small script to generate a token:

```javascript
// generate-token.js
const { StreamChat } = require('stream-chat');

const apiKey = 'YOUR_API_KEY';
const apiSecret = 'YOUR_API_SECRET';

const serverClient = StreamChat.getInstance(apiKey, apiSecret);
const token = serverClient.createToken('demo-user');

console.log('User Token:', token);
```

Run it:

```bash
node generate-token.js
```

### 2.4 Create a Channel (Optional)

The app automatically creates a `livestream` channel when it connects. If you want to pre-create it:

1. In the dashboard, go to **Explorer** → **Channels**.
2. Click **Create Channel**.
3. Set:
   - **Type**: `livestream`
   - **Channel ID**: `livestream-chat`
   - Add your user as a member.

> **Learn more**: [Stream Chat React Tutorial](https://getstream.io/chat/sdk/react/tutorial/) | [React SDK Docs](https://getstream.io/chat/docs/sdk/react/)

---

## Step 3 — Configure & Run the Project

### 3.1 Install Dependencies

```bash
cd aws-ivs-stream-chat
npm install
```

### 3.2 Create an Environment File

Copy the example file and fill in your credentials:

```bash
cp .env.example .env
```

Edit `.env` with your values:

```env
# Stream Chat credentials (required)
VITE_STREAM_API_KEY=your_stream_api_key
VITE_STREAM_USER_TOKEN=your_user_jwt_token
VITE_STREAM_USER_ID=demo-user
VITE_STREAM_USER_NAME=Demo User

# Stream Chat channel (optional — defaults to 'livestream-chat')
VITE_STREAM_CHANNEL_ID=livestream-chat

# AWS IVS playback URL — Low-Latency mode (optional — defaults to AWS test stream)
VITE_IVS_PLAYBACK_URL=https://your-channel.playback.live-video.net/api/video/v1/your-channel.m3u8

# AWS IVS Real-Time stage participant token — Real-Time mode (optional)
VITE_IVS_STAGE_TOKEN=your_stage_participant_token
```

### 3.3 Start the Development Server

```bash
npm run dev
```

Open [http://localhost:5173](http://localhost:5173) in your browser. You should see:

- The **video player** on the left (showing the IVS stream or a loading/error state).
- A **streaming mode toggle** in the title bar to switch between Low-Latency and Real-Time.
- The **chat sidebar** on the right (connected to Stream Chat).
- A **Hide Chat** button overlaid on the player to toggle the sidebar.

### 3.4 Build for Production

```bash
npm run build
npm run preview
```

---

## Project Structure

```
aws-ivs-stream-chat/
├── index.html                  # HTML shell — loads IVS Player SDK from CDN
├── .env.example                # Template for environment variables
├── package.json                # Dependencies and scripts
├── vite.config.ts              # Vite configuration
├── tsconfig.json               # TypeScript project references
├── tsconfig.app.json           # App TypeScript config
├── public/
│   └── vite.svg                # Favicon
└── src/
    ├── main.tsx                # React entry point
    ├── App.tsx                 # Main layout — mode toggle + player/stage + chat
    ├── App.css                 # All application styles
    ├── index.css               # Global reset and font config
    ├── vite-env.d.ts           # Typed environment variables
    ├── types/
    │   └── ivs.d.ts            # TypeScript declarations for IVS Player CDN API
    └── components/
        ├── IVSPlayer.tsx       # Amazon IVS Low-Latency video player wrapper
        ├── IVSRealTime.tsx     # Amazon IVS Real-Time stage (WebRTC)
        └── ChatSidebar.tsx     # Stream Chat message list + input (custom UI)
```

---

## How It Works

### Streaming Mode Toggle — `App.tsx`

The title bar contains a toggle with two modes:

- **Low-Latency** — Renders the `IVSPlayer` component for HLS playback. Best for large audiences watching a single broadcaster.
- **Real-Time** — Renders the `IVSRealTime` component for WebRTC stage participation. Best for interactive multi-party sessions.

Switching modes swaps the video component in real time; the chat sidebar remains connected throughout.

### Low-Latency Playback — `IVSPlayer.tsx`

The component loads the Amazon IVS Player from a CDN script (included in `index.html`). On mount it:

1. Checks `window.IVSPlayer` for SDK availability and browser support.
2. Creates a player instance and attaches it to a `<video>` element.
3. Loads the HLS playback URL from your IVS channel.
4. Listens for `STATE_CHANGED` and `ERROR` events to show loading/error UI.

### Real-Time Stage — `IVSRealTime.tsx`

The component uses the `amazon-ivs-web-broadcast` npm package to connect participants to an IVS stage. It:

1. Requests camera and microphone permissions via `getUserMedia`.
2. Wraps local tracks in `LocalStageStream` objects for publishing.
3. Creates a `Stage` with a `StageStrategy` that publishes local streams and subscribes to all remote participants with `AUDIO_VIDEO`.
4. Listens for stage events (`STAGE_PARTICIPANT_STREAMS_ADDED`, `STAGE_PARTICIPANT_LEFT`, etc.) to build a participant grid.
5. Renders each participant's video in a responsive grid layout. Local audio is excluded from playback to prevent echo.
6. Provides **Join Stage** and **Leave Stage** controls with a connection status indicator.

### Real-Time Chat — Stream Chat React

The app uses Stream Chat React's built-in `<MessageList>` and `<MessageInput>` components, wrapped in `<Chat>` and `<Channel>` context providers. This provides:

- Real-time message delivery via WebSocket
- Typing indicators and read receipts
- Message reactions and threading
- File uploads and URL previews

### Connection & State — `App.tsx`

On mount, the App component:

1. Creates a Stream Chat client via `new StreamChat(apiKey)`.
2. Connects the user with `chatClient.connectUser()`.
3. Creates and watches a `livestream`-type channel.
4. Passes the client and channel to `<Chat>` and `<Channel>` providers.
5. Renders the active video component (IVSPlayer or IVSRealTime) and the chat sidebar in a flex layout.

---

## Customization

### Change the Accent Color

The magenta accent (`#d946ef`) is used throughout the CSS for the mode toggle, buttons, and the loading spinner. To change it, update these values in `src/App.css`:

```css
.mode-toggle-btn.active { background: #your-color; }
.rt-join-btn            { background: #your-color; }
.loading-spinner        { border-top-color: #your-color; }
```

### Use a Different Channel Type

The app uses Stream Chat's `livestream` channel type by default. You can switch to `messaging` (which enables all members to send messages by default) by updating the channel creation in `App.tsx`:

```tsx
const ch = chatClient.channel('messaging', CHANNEL_ID, {
  name: 'Live Stream Chat',
});
```

### Add Message Reactions

Stream Chat supports reactions out of the box. You can extend `ChatSidebar.tsx` to show reaction buttons per message using the `channel.sendReaction()` method.

### Add Multiple Users

Open the app in multiple browser tabs or windows, each with different `VITE_STREAM_USER_ID` and `VITE_STREAM_USER_TOKEN` values, to see real-time chat between users.

### Real-Time Stage with Multiple Participants

To test multi-party Real-Time mode:

1. Create multiple participant tokens (each with a different `userId`).
2. Open the app in separate browser tabs, each with a different `VITE_IVS_STAGE_TOKEN`.
3. Switch to Real-Time mode and click **Join Stage** in each tab.

---

## Troubleshooting

| Problem | Solution |
|---|---|
| **"IVS Player SDK not loaded"** | Check your internet connection — the SDK loads from `player.live-video.net`. Make sure ad blockers aren't blocking it. |
| **"Stream unavailable"** | The IVS channel is likely offline. Start streaming with OBS or use the default test stream URL. |
| **"Missing Stream Chat credentials"** | Create a `.env` file from `.env.example` and add your Stream API key and user token. |
| **"Failed to connect to chat"** | Verify your API key and user token are correct. Check the browser console for detailed errors. |
| **Chat messages not appearing** | Ensure the user has permission to read/write in the `livestream` channel. In the Stream Dashboard, check channel type permissions. |
| **"Camera/microphone access denied"** | Real-Time mode needs camera and mic permissions. Click the browser's permission prompt or update site settings. |
| **"No stage participant token provided"** | Add a valid `VITE_IVS_STAGE_TOKEN` to your `.env` file. Generate one from the AWS Console or the `CreateParticipantToken` API. |
| **Real-Time stage not connecting** | Participant tokens are short-lived. Generate a fresh one. Ensure the stage is active in the AWS Console. |
| **Build warnings about chunk size** | Expected — the Stream Chat SDK and IVS Real-Time SDK are large. For production, consider code splitting with dynamic imports. |

---

## Resources

### Amazon IVS

- [What is Amazon IVS?](https://docs.aws.amazon.com/ivs/latest/LowLatencyUserGuide/what-is.html)
- [What is IVS Real-Time Streaming?](https://docs.aws.amazon.com/ivs/latest/RealTimeUserGuide/what-is.html)
- [Getting Started with IVS Real-Time](https://docs.aws.amazon.com/ivs/latest/RealTimeUserGuide/getting-started-introduction.html)
- [IVS Real-Time Broadcast SDK — Web](https://docs.aws.amazon.com/ivs/latest/RealTimeUserGuide/broadcast-web.html)
- [IVS Player SDK — Web](https://docs.aws.amazon.com/ivs/latest/LowLatencyUserGuide/web-getting-started.html)
- [Amazon IVS Real-Time Web Demo (React)](https://github.com/aws-samples/amazon-ivs-realtime-web-demo-reactjs)
- [Amazon IVS Player Web Sample](https://github.com/aws-samples/amazon-ivs-player-web-sample)

### Stream Chat

- [Stream Chat React SDK Docs](https://getstream.io/chat/docs/sdk/react/)
- [Stream Chat React Tutorial](https://getstream.io/chat/sdk/react/tutorial/)
- [Stream Dashboard](https://dashboard.getstream.io/)
- [Stream Chat API Reference](https://getstream.io/chat/docs/rest/)

### This Project

- Built with [React 19](https://react.dev/) + [TypeScript](https://www.typescriptlang.org/) + [Vite](https://vite.dev/)
- Low-Latency Video: [amazon-ivs-player v1.49.0](https://www.npmjs.com/package/amazon-ivs-player) (CDN)
- Real-Time Video: [amazon-ivs-web-broadcast v1.33.0](https://www.npmjs.com/package/amazon-ivs-web-broadcast) (npm)
- Chat: [stream-chat-react v13](https://www.npmjs.com/package/stream-chat-react) + [stream-chat v9](https://www.npmjs.com/package/stream-chat) (npm)
