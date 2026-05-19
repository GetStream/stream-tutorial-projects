# ChatWithSkills

A SwiftUI iOS chat app built end-to-end with the [Stream Swift Agent Skill](https://www.skills.sh/getstream/agent-skills/stream-swift). This repo is both a working Stream Chat sample and a demonstration of how the `stream-swift` skill scaffolds, wires, and verifies Stream-powered Swift apps from a single prompt.

---

## What is the Stream Swift Agent Skill?

`stream-swift` is an open-source [Agent Skill](https://www.skills.sh) published by [GetStream](https://getstream.io) that teaches your coding agent (Cursor, Claude Code, Codex, Windsurf, etc.) how to build and integrate Stream **Chat**, **Video**, and **Feeds** in Swift apps.

It is not a library you import. It is a structured bundle of instructions, rules, and reference blueprints that the agent reads on demand so that when you ask "build me a SwiftUI chat app" or "add video calls to this Xcode project," it follows a deterministic, Stream-blessed flow instead of guessing.

The skill lives at:

```text
~/.agents/skills/stream-swift/
├── SKILL.md                       # router + intent classifier (entrypoint)
├── RULES.md                       # non-negotiable Stream/Swift rules
├── builder.md                     # build & integration flow
├── sdk.md                         # shared lifecycle/auth/state patterns
└── references/
    ├── CHAT-SWIFTUI.md            # Chat + SwiftUI setup + gotchas
    ├── CHAT-SWIFTUI-blueprints.md # Chat + SwiftUI view blueprints
    ├── CHAT-UIKIT.md              # Chat + UIKit setup + gotchas
    ├── CHAT-UIKIT-blueprints.md   # Chat + UIKit view controller blueprints
    ├── VIDEO-SWIFTUI.md           # Video + SwiftUI setup
    ├── VIDEO-SWIFTUI-blueprints.md
    ├── VIDEO-UIKIT.md
    ├── VIDEO-UIKIT-blueprints.md
    ├── LIVESTREAM-SWIFTUI.md      # creator/viewer, goLive/stopLive, HLS
    ├── LIVESTREAM-SWIFTUI-blueprints.md
    ├── FEEDS-SWIFTUI.md           # Feeds SDK patterns (SwiftUI + UIKit)
    ├── FEEDS-SWIFTUI-blueprints.md
    └── COMBINED-CHAT-VIDEO.md     # name-collision + file isolation guide
```

---

## What it does and can do

The skill gives an agent the ability to:

### Build new Stream apps from scratch

- Scaffold a SwiftUI **or** UIKit iOS app wired to Stream Chat, Video, Feeds, or a combination.
- Build a **livestream** experience with creator/viewer modes, `goLive` / `stopLive`, backstage, and HLS playback.
- Set up a **combined Chat + Video** app with the proper file-isolation pattern so the colliding SDK type names (`User`/`UserInfo`, `Token`/`UserToken`, `ViewFactory`) don't collide at compile time.

### Integrate Stream into an existing app

- Detect whether you have a `.xcodeproj`, `.xcworkspace`, `Package.swift`, or `Podfile`, and preserve your existing package manager.
- Preserve your existing UI layer (no forced SwiftUI ↔ UIKit conversions) and navigation/DI architecture.
- Add the minimum composition points needed for the requested Stream surface.

### Bootstrap credentials and seed data automatically

- Use the [Stream CLI](https://github.com/GetStream/stream-cli) to read your app's API key (`stream config get-app`) and generate a real user token (`stream token <user_id>` or `stream token <user_id> --ttl 1h`).
- Optionally seed 3–5 realistic channels with random usernames so the app shows real data on first launch — no placeholder strings in your code.
- Keep the API **secret** out of your app entirely (CLI/server-side only).

### Answer reference questions

- Look up how a specific Stream SwiftUI/UIKit type, modifier, or hook works.
- Map a feature request ("custom message composer," "thread list," "permissions for backstage") to the correct blueprint file without dumping unrelated documentation.

### Enforce Stream-blessed rules

The skill ships a [`RULES.md`](file:///Users/amosgyamfi/.agents/skills/stream-swift/RULES.md) the agent reads once per session. The most important ones:

- **No wrapper/bridge abstractions.** Use `StreamVideo`, `StreamChat`, `CallViewModel`, `ChatClient` directly — never `CallManager`, `VideoCallBridge`, `StreamWrapper`, etc.
- **Client lifetime is owned.** SDK clients are created once in `App.init()`, `AppDelegate`, or an app-scoped service — never in a `View` body or computed property.
- **Secrets stay server-side.** The API secret never enters app code, `Info.plist`, or chat.
- **Main-actor discipline.** UI state changes hop back to the main actor.
- **Project ownership.** Don't convert UIKit ↔ SwiftUI, don't replace CocoaPods with SPM, don't flatten existing coordinators — unless asked.

### Operate on a deterministic 4-track flow

Every request is routed into one of four tracks before the agent touches a tool:

| Track | When | What happens |
|---|---|---|
| **A — New app** | "Build me a SwiftUI chat app" | Full scaffold: detect → choose lane → install → wire → verify |
| **B — Existing app** | "Add Stream Video to this project" | Detect → preserve architecture → integrate → verify |
| **C — Reference lookup** | "How does `ChannelList` work in Chat SwiftUI?" | Load only the matching reference file(s) |
| **D — Bootstrap / setup** | "Just install Stream and wire auth" | Detect → install → auth wiring → stop |

---

## This repo

`ChatWithSkills` is the output of running the skill against an empty SwiftUI iOS project with the prompt _"build me a SwiftUI chat app using Stream"_. The relevant files:

```text
ChatWithSkills/
├── ChatWithSkillsApp.swift   # App entrypoint — owns the ChatClient lifetime
├── RootView.swift            # Auth-aware root (Login ↔ ChannelList)
├── LoginView.swift           # Token + user-id entry / CLI-generated token flow
├── ChannelListScreen.swift   # Stream Chat SwiftUI ChannelList
└── StreamConfig.swift        # API key + token wiring (no secret)
```

It follows every rule above: no wrappers, client owned at app launch, secret never present, channels seeded via the Stream CLI rather than hardcoded.

---

## How to use the skill

### 1. Install it

The skill is already installed at `~/.agents/skills/stream-swift/`. To install it on another machine:

```bash
npx skills add https://github.com/getstream/agent-skills --skill stream-swift
```

Or clone manually:

```bash
git clone https://github.com/getstream/agent-skills.git
cp -R agent-skills/skills/stream-swift ~/.agents/skills/
```

Agents that respect `~/.agents/skills/` (Cursor, Claude Code, Codex, etc.) will pick it up automatically on their next session.

### 2. Install prerequisites

- **Xcode 15+** (the skill won't scaffold an `.xcodeproj` for you — create the empty app first).
- **[Stream CLI](https://github.com/GetStream/stream-cli)** — needed for credential fetching and token generation:

```bash
brew install GetStream/stream-cli/stream-cli
stream config new   # log in with your Stream API key + secret once
```

- A **Stream account** with at least one app — sign up at [getstream.io](https://getstream.io).

### 3. Invoke the skill

Just describe what you want. The skill's intent classifier matches keywords and routes the work automatically. Sample prompts:

**Build a new app**

> Build me a SwiftUI chat app using Stream. Seed a few channels so I can see data on first launch.

> Create a SwiftUI livestream app with creator and viewer modes.

> Scaffold a UIKit chat app and wire it to Stream.

**Integrate into an existing app**

> Add Stream Video calls to this Xcode project. Keep the existing UIKit navigation.

> Wire Stream Chat into my SwiftUI app — the package manager is SPM, don't switch to Cocoapods.

> Integrate Feeds into this app and build a basic timeline screen.

**Bootstrap / setup only**

> Just install the Stream Chat SwiftUI package and wire auth — I'll build the UI myself.

**Reference lookup**

> How does `CallViewModel` handle incoming-call state in Video SwiftUI?

> Show me the Chat SwiftUI blueprint for a custom message composer.

> What's the right way to handle name collisions in a combined Chat + Video app?

### 4. Answer the one upfront question

For Tracks A, B, and D, the agent will ask **one** consolidated question about credentials, token expiry, and (for Chat) channel seeding. Answer it once and the agent executes the rest of the CLI sequence — `stream config get-app`, `stream token <user_id>`, `stream chat channel create ...` — without pausing for further confirmation.

If you'd rather paste credentials yourself, say so in your reply and the agent will skip the CLI calls.

### 5. Verify

When the agent stops, it will report a short verification checklist. For this repo that meant:

- Stream Chat SwiftUI package resolves in `ChatWithSkills.xcodeproj`.
- `ChatClient` is initialized in `ChatWithSkillsApp` once, before any view renders.
- `LoginView` connects the seeded user with the CLI-generated token.
- `ChannelListScreen` renders the seeded channels on first launch.
- Logging out cleanly disconnects the current user.

---

## Running this repo

```bash
git clone <this-repo>
cd ChatWithSkills
open ChatWithSkills.xcodeproj
```

1. In Xcode, let Swift Package Manager resolve `stream-chat-swiftui`.
2. Open `StreamConfig.swift` and paste your **API key** and a **user token** (generate one with `stream token <user_id>`).
3. Build & run on an iOS 17+ simulator or device.
4. The login flow uses the user id whose token you generated; the channels seeded via the CLI will appear immediately.

> **Never** commit your API secret. Only the API key and user token belong in `StreamConfig.swift`.

---

## Related resources

- Skill page: <https://www.skills.sh/getstream/agent-skills/stream-swift>
- Source repo: <https://github.com/getstream/agent-skills>
- Stream Chat SwiftUI SDK: <https://github.com/GetStream/stream-chat-swiftui>
- Stream Video iOS SDK: <https://github.com/GetStream/stream-video-swift>
- Stream Feeds Swift SDK: <https://github.com/GetStream/stream-feeds-swift>
- Stream CLI: <https://github.com/GetStream/stream-cli>
- Stream Swift docs: <https://getstream.io/chat/docs/sdk/ios/>

---

## License

This sample app is provided under the same license as the Stream Swift agent skill — see the [LICENSE](https://github.com/getstream/agent-skills/blob/main/LICENSE) in the `agent-skills` repository.
