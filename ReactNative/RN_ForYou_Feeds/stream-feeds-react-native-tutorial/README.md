# Stream Feeds React Native Tutorial

A complete React Native activity feed application built with Stream's Activity Feed V3 SDK. This app demonstrates how to build scalable, real-time activity feeds with features like:

- User and timeline feeds
- Activity posting with text and images
- Reactions (likes)
- Comments
- Follow/Unfollow functionality
- "For You" personalized feed exploration

## Prerequisites

- Node.js (v22 or v24 recommended)
- Yarn
- Expo CLI
- iOS Simulator (for iOS) or Android Emulator (for Android)

## Installation

1. Install dependencies:

```bash
yarn install
```

2. The app comes pre-configured with demo credentials in `user.ts`. For production, replace these with your own Stream API credentials.

## Running the App

### iOS

```bash
yarn ios
```

### Android

```bash
yarn android
```

### Development Server

```bash
yarn start
```

Then press `i` for iOS or `a` for Android.

## Project Structure

```
├── app/
│   ├── _layout.tsx          # Root layout with StreamFeeds provider
│   ├── comments-modal.tsx   # Comments modal screen
│   └── (tabs)/
│       ├── _layout.tsx      # Tab navigation layout
│       ├── index.tsx        # Home screen (timeline)
│       └── explore.tsx      # For You / Explore screen
├── components/
│   ├── activity/
│   │   ├── Activity.tsx         # Activity card component
│   │   ├── ActivityComposer.tsx # Post composer
│   │   ├── ActivityList.tsx     # Activity list with pagination
│   │   ├── ImagePicker.tsx      # Image upload component
│   │   └── Reaction.tsx         # Like button component
│   ├── comments/
│   │   ├── Comment.tsx          # Comment item
│   │   ├── CommentComposer.tsx  # Comment input
│   │   └── CommentList.tsx      # Comments list
│   ├── follows/
│   │   └── follow-button.tsx    # Follow/Unfollow button
│   ├── themed-text.tsx          # Themed text component
│   └── themed-view.tsx          # Themed view component
├── contexts/
│   └── own-feeds-context.tsx    # User feeds context
├── hooks/
│   └── use-color-scheme.ts      # Color scheme hook
└── user.ts                      # API credentials
```

## Features

### Home Tab
- View your timeline feed with posts from followed users
- Create new posts with text and optional images
- Like posts and view like counts
- Access comments for any post

### For You Tab
- Explore popular content from the community
- Follow new users directly from their posts
- Discover trending activities

### Comments
- View and add comments on any activity
- Real-time comment updates
- Pagination for large comment threads

## Learn More

- [Stream Activity Feeds Documentation](https://getstream.io/activity-feeds/docs/)
- [React Native SDK Reference](https://getstream.io/activity-feeds/sdk/react-native/)
- [Expo Documentation](https://docs.expo.dev/)

## License

This tutorial project is provided for educational purposes.
