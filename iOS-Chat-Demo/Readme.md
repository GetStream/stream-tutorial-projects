
# Make Your First iPhone Chat App With the Stream iOS / Swift SDK 
![header](https://github.com/GetStream/swift-and-swiftui-tutorial-projects/blob/main/iOS-Chat-Demo/img/ioschatapp.jpg)

## Overview

Let me begin by giving you a sneak peek of what you will walk away with after reading this article. At the end of the tutorial, you will have a real-time chat messaging app that can be extended and customized to meet your use case. Stream Chat provides you with all the features you need to build engaging messaging experiences.

## Explore the app

The chat app you will create in this tutorial provides:

**Offline support**: send messages, edit messages and send reactions while offline

![Offline support](https://github.com/GetStream/swift-and-swiftui-tutorial-projects/blob/main/iOS-Chat-Demo/img/offlineSupportReactions2.gif)

**Link previews**: generated automatically when you send a link

![Link](https://github.com/GetStream/swift-and-swiftui-tutorial-projects/blob/main/iOS-Chat-Demo/img/link2.gif)

**Commands**: type `/` to use commands like `/giphy`

![Giphy](https://github.com/GetStream/swift-and-swiftui-tutorial-projects/blob/main/iOS-Chat-Demo/img/giphy2.gif)

**Reactions**: tap-and-hold on a message bubble to add a reaction

![Reactions](https://github.com/GetStream/swift-and-swiftui-tutorial-projects/blob/main/iOS-Chat-Demo/img/reactions2.gif)

**Attachments**: use the paperclip button in `MessageInputView` to attach images and files

![Attachments](https://github.com/GetStream/swift-and-swiftui-tutorial-projects/blob/main/iOS-Chat-Demo/img/attachment2.gif)

**Edit message**: long-press on your message for message options, including editing

![Edit](https://github.com/GetStream/swift-and-swiftui-tutorial-projects/blob/main/iOS-Chat-Demo/img/edit2.gif)

**Threads**: start message threads to reply to any message

![Threads](https://github.com/GetStream/swift-and-swiftui-tutorial-projects/blob/main/iOS-Chat-Demo/img/threads2.gif)


## Prerequisites

- Ensure that you have the required software installed. We will be using Xcode 13.4.1 for this tutorial.
- We will use an API key that points to the Stream’s tutorials’ environment. This key is used for prototyping and debugging. When you want to build a real chat using Stream, you will need an API key. You can [sign up for a free Chat trial account](https://getstream.io/chat/trial/) to get your API key.

## **Resources**

- The [completed project](https://github.com/GetStream/swift-and-swiftui-tutorial-projects/blob/main/iOS-Chat-Demo/iOSChatDemo.zip) for this tutorial is available on GitHub.
- **Extend and customize the chat experience**. After creating the chat app, you may want to extend and modify it. Luckily, we have excellent documentation for theming and customization
    - [Theming documentation](https://getstream.io/chat/docs/sdk/ios/uikit/theming/)

## Start with a Storyboard project in Xcode

This tutorial focuses on how to create a chat messaging app using Storyboard (UIKit). You can get the SwiftUI version from this [video](https://youtu.be/Gk14JlvXO6k)
 and [article](https://getstream.io/tutorials/swiftui-chat/).

Open Xcode and create a new Swift/Storyboard project. 
- Choose **iOS** from the list of platforms
- Choose the **App** template
- Use "**StoryChat**" for the product name
- Select **Storyboard** in the Interface options
- Select **Swift** as the language and press the "**Next**" button.

## Fetch the iOS SDK
To start, you need to fetch the [iOS Chat SDK](https://github.com/GetStream/stream-chat-swift) from GitHub. You can install the SDK using CocoaPods but we will use Swift Package Manager to make things easy. 

- Go to **File > Add Packages...**
- Paste the following URL in the search field at the top right: **[https://github.com/getstream/stream-chat-swift](https://github.com/getstream/stream-chat-swift)**
- Under **Dependency Rule** go with the "**Up to Next Major Version**" option and enter `4.0.0` as the version
- Click the **Add Package** button
- Add both `StreamChat` and `StreamChatUI` packages to the project as dependencies

## Explore the app structure

Let’s take a few minutes to explore how Xcode organizes the files. In the navigator, there are a few files that are worth mentioning. 

- Main app file
- AppDelegate
- ViewController
- SceneDelegate
- Package dependencies
    - **Difference:** A better way to identify what's different between 2 instances.
    - **StreamChat:** This is the official iOS SDK for [Stream Chat](https://getstream.io/chat/sdk/ios/)
    - **StreamChatTestHelpers:** Test Helpers used by Stream iOS SDKs for testing purposes
    - **Swifter:** A tiny HTTP server engine. It is written in Swift.

## Understanding the `AppDelegate.swift`

The app delegate is the root object of the chat app. UIKit creates the app delegate object early in the app’s launch cycle. So it’s always present. It handles the handle the following tasks:

- Initializes the app’s central data structures
- Scenes configurations of the app
- Responding to notifications originating from outside the app
    - such as low-memory warnings
    - download completion notifications
- Registers required services at launch time, such as push notifications

To begin, open `AppDelegate.swift` and extend the `ChatClient` functionality at the top of the file. You can do this by appending the code below to the top of the file. 

```swift
// AppDelegate.swift
// 1. Extend the ChatClient functionality

import StreamChat

extension ChatClient {
		// Add an optional chat client variable
    static var shared: ChatClient!
}
```

## What is a view controller? `ViewController.swift`

The view controller manages the app’s interface, navigation, and user interactions. Its content fills the main window of the chat app. Replace the content of the file with the sample code below. This will display the channel list screen when you run the app. 

```swift
// ViewController.swift
// 2. Fill the main window of the app

import StreamChat
import StreamChatUI
import UIKit

// Display the channel list screen
class DemoChannelList: ChatChannelListVC {}
```

## Use Scene delegate to set up the SDK: `SceneDelegate.swift`

When the app launches, we must find a way to respond to life-cycle events occurring within the scene. To handle these events, we should define a core method in the body of the `SceneDelegate.swift` file. 

## Set up the SDK

To set up the SDK, you need an API key. In this article, we will use an API key that points to the Stream’s tutorials’ environment. This key is used for prototyping and debugging. When building a real chat using Stream, you will need your own API key. You can [sign up for a free Chat trial account](https://getstream.io/chat/trial/) to get your own API key. 

Begin by substituting the content of `SceneDelegate.swift` with the code below. 

```swift
// SceneDelegate.swift

// Respond to life-cycle events using the method "scene"

func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
) {
		// Define the API key
    let config = ChatClientConfig(apiKey: .init("dz5f4d5kzrue"))

    /// user id and token for the user
    let userId = "tutorial-droid"
    let token: Token =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoidHV0b3JpYWwtZHJvaWQifQ.NhEr0hP9W9nwqV7ZkdShxvi02C5PR7SJE7Cs4y7kyqg"

    /// Step 1: Create an instance of ChatClient and share it using the singleton
    ChatClient.shared = ChatClient(config: config)

    /// Step 2: User Authentication (Connect the user to chat). 
    ChatClient.shared.connectUser(
        userInfo: UserInfo(
            id: userId,
            name: "Tutorial Droid",
            imageURL: URL(string: "https://bit.ly/2TIt8NR")
        ),
        token: token
    )

    /// Step 3: Create the ChannelList view controller
    let channelList = DemoChannelList()
    let query = ChannelListQuery(filter: .containMembers(userIds: [userId]))
    channelList.controller = ChatClient.shared.channelListController(query: query)

    /// Step 4: Similar to embedding with a navigation controller using Storyboard
    window?.rootViewController = UINavigationController(rootViewController: channelList)
}
```

## A step-by-step guide

## Step 1

In `SceneDelegate.swift`, you define the API key and initialize the shared `ChatClient` using an API key. This API key points to a tutorial environment, but you can **[sign up for a free Chat trial](https://getstream.io/chat/trial/)** to get your own later.

## Step 2

User Authentication (connect the user to chat). Create and connect the user with the `ChatClient.connectUser` method and use a pre-generated user token, in order to authenticate the user. In a real-world application, your authentication backend would generate such a token at login / signup and hand it over to the mobile app. For more information, see the **[Tokens & Authentication](https://getstream.io/chat/docs/ios-swift/tokens_and_authentication/)**
 page.

## Step 3

You should use the `DemoChannelList` component and initialize the `channelListController` controller with a `ChannelListQuery`. We’re using the default sort option which orders the channels by `last_updated_at` time, putting the most recently used channels on the top. For the filter, we’re specifying all channels of type `messaging` where the current user is a member. The documentation about **[Querying Channels](https://getstream.io/chat/docs/ios-swift/query_channels/)** covers this in more detail.

## Step 4

Finally, set the `channelList` as the root of a new `UINavigationController` and make it the root of our `window`


## Run, test the app, and explore all the chat features

You can now run the app to see the built-in list of channels and explore all the features of the chat app. Congrats on getting your chat experience up and running! 

## Where do I go next?
A companion video tutorial of this article will be available soon on the Stream Developers YouTube Channel. You could check it out and subscribe. You can get the SwiftUI version from this [video](https://youtu.be/Gk14JlvXO6k) on the same channel and [article](https://getstream.io/tutorials/swiftui-chat/). Enjoy!!!.

