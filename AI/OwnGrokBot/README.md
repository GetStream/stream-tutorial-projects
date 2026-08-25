# StreamBot

A team of AI teammates you chat with. Each one owns a lane of work, plans in the
open, stops where you told it to stop, and learns your workflow by watching you
do it once.

StreamBot is an iOS 27 / SwiftUI app built on **Stream Chat SwiftUI** for the
conversation and **Core AI** for the thinking. Every model runs on the device:
no inference server, no prompt leaves the phone. Only the chat itself — messages,
channels, presence, typing — goes through Stream.

It is modelled on [Grok Bot](https://apps.apple.com/us/app/grok-bot/id6794501026):
hire a bot, give it work in a thread, watch it work, approve what it produces,
teach it to do it again, and extend it with plugins. The difference is where the
work happens. Grok Bot drives a browser on a computer in the cloud; StreamBot's
tools are the ones a phone genuinely has — the plugin marketplace connects bots to
your calendar, reminders, contacts, and threads, read-only and on device — and for
everything beyond that its bots say plainly what they would need from you instead
of pretending to have signed in somewhere.

---

## 1. What it does

### Nine seeded teammates, plus two you can hire

The roster Grok Bot lists on [x.ai/bot](https://x.ai/bot) — Sales Outbound, Talent
Scout, Inbox Manager, Expense Manager, Invoice Collector, Account Health, Bug
Reproduction, Competitive Intel, Chief of Staff — plus the two jobs that page
added later: **Paid Media** and **Product Performance**.

| Bot | Role | Lane | Runs | In Stream |
| --- | --- | --- | --- | --- |
| Nova | Chief of Staff | Coordination | On its own | Seeded |
| Ada | Sales Outbound | Sales | Queues for review | Seeded |
| Ravi | Talent Scout | Recruiting | Queues for review | Seeded |
| Mira | Inbox Manager | Inbox | Never sends without you | Seeded |
| Otto | Expense Manager | Finance | Queues for review | Seeded |
| Juno | Invoice Collector | Finance | Queues for review | Seeded |
| Sable | Account Health | Customer Success | Queues for review | Seeded |
| Pike | Bug Reproduction | Engineering | On its own | Seeded |
| Vesper | Competitive Intel | Research | On its own | Seeded |
| Lumen | Paid Media | Growth | Queues for review | Hire from Team |
| Reed | Product Performance | Product | On its own | Hire from Team |

A bot's lane is not decoration: it picks the charter in its system prompt and the
verbs its plans are written with, which is why Mira produces triage steps and
Pike produces repro steps without either being told so in every message.

Bots live in Stream as ordinary chat users. Name, lane, tagline, accent, symbol,
and approval policy travel in the Stream user's custom data, so every device that
connects sees the same roster with no backend of our own. You can also hire new
teammates from the Team tab, which creates the Stream user and its thread.
Lumen and Reed are hire-only: they are not in the Stream seed, so they get a
thread but cannot post until a token is minted for them.

### Runs you can watch

One message to a bot produces two messages back, both authored by the bot so they
arrive as incoming messages in the thread:

1. **A run card** — the plan, as a live object in the message's `extraData`. It is
   edited in place as steps tick from pending to active to done, so the plan you
   are watching is literally the one the runtime is walking. Approve, Reject,
   Stop, and Try again live on the card, and it stays interactive hours later.
2. **A prose reply** — the draft, digest, or write-up, streamed in token by token.

The plan is a separate message rather than text inside the reply precisely because
it has to outlive the reply.

### Approval gates that are enforced, not promised

Each bot has one of three policies, and the runtime — not the prompt — enforces
it. A *never sends without you* bot cannot mark a run finished without a tap; its
run parks at `awaitingApproval` and the composer says so.

### Teach a routine by doing it once

Long-press any message in a thread and choose **Teach as routine**. The bot reads
the conversation, distils it into a named workflow with a trigger and ordered
steps, and stores it on device. Next time a request matches that trigger, the
planning call is skipped entirely and the taught steps are used instead — faster
and closer to what you actually wanted than anything re-derived.

On the bot's detail sheet a routine can also be **scheduled**: a daily hour in
the timezone from Settings. Grok Bot's cloud computer can fire that at 7:00
whether the laptop is open or not. StreamBot's bots think on this phone, so a
due routine starts the next time you open the app after that hour — not while
the device is asleep. That limit is stated next to the picker.

### Memory

While it works, a bot extracts standing preferences ("always cc me", "keep it to
three lines") and durable facts about your world, and folds them into its own
system prompt on later runs. Memory is per-bot, on-device, and editable in the
bot's detail sheet.

### Plugins: skills to work with, and sources to read

**Team → puzzle icon**, or **Browse** on any teammate's page, opens the
marketplace. It has the two tabs Grok Bot has — Marketplace and Yours — and the
same two-level model: a plugin is *added* once for the team, then *enabled* per
bot. Adding Calendar and then being asked which of the teammates should have it
would be worse than adding it and finding it already on for the two that plan
your week, so enablement defaults by lane and keeps applying to bots you hire
later. After **Add**, the marketplace switches to Yours and says the plugin is
ready in this app — Grok Bot 1.3's "plugin integrations return straight into
the app", without a detour through a browser.

A plugin carries one or both of:

* **Skills** — a named way of working: the steps, the shape of the output, the
  boundaries. The skill that matches a request is added to the bot's system
  prompt for that run, and any skill can be asked for by name with `/` in the
  composer.
* **A connector** — a real source on this phone, exposed to the model as a
  FoundationModels `Tool`. The model decides mid-answer that it needs it, the
  read happens locally, and the answer is built on what came back.

| Plugin | Kind | What it does |
| --- | --- | --- |
| Calendar | Connector + 2 skills | Reads real events for a day or a range through EventKit. Day brief, meeting prep. |
| Reminders | Connector + 1 skill | Reads open reminders and due dates. Overdue first. |
| Contacts | Connector + 1 skill | Looks a person up so a draft uses their real name, company, and email. |
| Threads | Connector + 1 skill | Searches everything said in your threads, through Stream's own message search. |
| Clock & Dates | Connector | Today's real date and date arithmetic. The smallest plugin here and the one that prevents the most nonsense: a model has no clock, so "by Thursday" is otherwise invented. |
| Meeting Notes | 1 skill | Decisions, owners, open questions — in that order. |
| Bug Reports | 1 skill | Repro steps first, inference labelled as inference. |
| Cold Outreach | 2 skills | Under 90 words, one ask, no adjectives. Plus a follow-up that adds something. |
| Weekly Review | 1 skill | Changed, stuck, next. |
| Account Health | 1 skill | Risk flags ranked by how soon someone must act, with the evidence attached. |
| Paid Media | 1 skill | Audience, offer, three ad angles, budget as a recommendation — never as spend already moved. |
| Product Performance | 1 skill | What moved, what it means, and the one decision that is due. |

Clock & Dates and Threads are added on first launch, because neither needs a
permission and both are useful to every teammate.

Three rules hold across every connector. They are **read-only** — writing to a
calendar is exactly the kind of side effect the approval model exists to
prevent. Their answers are **small and capped**, because a tool result is prompt
tokens on a phone-sized model. And they are **honest about emptiness**: "no
events" and "no access" are different answers, both said plainly, because a
model handed nothing will otherwise produce something plausible.

Nothing in the catalogue is a placeholder. There is no Gmail plugin, because
shipping one would mean pretending to a mailbox this app has no route to.

When a bot actually calls a connector, the step on the run card is re-tagged with
that surface — so the plan shows Calendar on the step that really read the
calendar, rather than on the step that planned to. On a teammate's page, live
surfaces are the coloured pills; the grey ones still only name where a step
belongs.

Connectors need Apple Intelligence: tool calling is a trained behaviour, and the
Core AI zoo bundles are decode-only language bundles that will never emit a call.
Those models keep the skills half of every plugin, which is instructions and
works anywhere.

### The Ops Room

A room with the whole team in it. Mention a teammate to hand them something
directly. Say nothing and Nova, the lead, reads the request, picks whoever owns
that kind of work, posts the handoff as a visible message, and that teammate takes
it from there. The handoff is a message rather than a silent decision because your
next question in a room is always "who has this?" — and because that is where you
can tell the lead it chose wrong.

### Dictation, not voice notes

The mic in the strip above the composer dictates into the draft with
`SpeechAnalyzer` + `SpeechTranscriber`. Words appear while you are still speaking
and are revised as the transcriber settles: the unsettled tail renders in grey,
committed speech in full colour, and a live waveform driven from the mic tap
proves the microphone is being heard before any text exists. Stream's own
hold-to-record voice recorder is switched off in `ComposerConfig`, because two
mics an inch apart doing different things is a coin flip for the user.

Recording and sending are separate, matching Grok Bot 1.3. **Stop** ends the
capture and opens a review: **Send** posts the transcript as a message, **Keep
in draft** leaves it in the composer, **Discard** throws it away. A misheard
sentence cannot fire a run.

### Share from other apps

Grok Bot 1.3 added sharing from other apps. StreamBot takes the same inbound
without a share-extension target:

* the URL scheme `streambot://handoff?text=…`
* "Open in" for plain text files
* **Team → download icon**, which hands off whatever is on the clipboard

A sheet then asks which teammate gets the text, and that bot starts a run.
Finished run cards also have a **Share** control, so a draft can leave the app
the same way it arrived.

### Settings: haptics, notifications, reconnect

The fourth tab is Settings, the surface Grok Bot 1.3 put haptics on.

* **Haptics** — a tap when a bot starts, needs you, finishes, or is hired.
* **Notifications** — a local ping when a bot finishes, fails, or parks a draft
  for approval. Off per teammate from Settings or from that bot's page. Asked
  for at the switch, not on first launch.
* **Schedules** — the timezone scheduled routines use.
* **Reconnect runtime** — Grok Bot reconnects a cloud computer. StreamBot
  unloads the on-device model session and drops in-flight work, so the next
  message loads a fresh session.

The Team tab itself shows how many bots are working and how many need you.
Thread rows waiting on approval wear an orange **Needs you** pill.

---

## 2. Models, and what each one is for

The Models tab is a real tab rather than a buried setting: on a phone, the choice
between a 0.8 B and a 2 B model is the difference between an answer in four
seconds and one in twenty. Settings sits next to it, because haptics,
notifications, and reconnecting the runtime are not model choices.

### Thinking — one model, five jobs

Whichever model you pick in **Models** does all of the language work: planning a
run, working each step, synthesising the reply, distilling a taught routine, and
extracting memory.

| Model | Bundle | Size | Notes |
| --- | --- | --- | --- |
| Apple Foundation Model | built in | — | `SystemLanguageModel.default` via `FoundationModels`. Supports guided generation, so plans, routines, and memory come back as typed values that cannot be malformed. Needs Apple Intelligence on, and cannot run inference in the Simulator. |
| Qwen3.5 0.8B | `qwen3_5_0_8b_decode_int8hu_perchan_sym` | 1.3 GB | Fastest of the zoo set. A thinking model — reasoning streams separately from the answer. |
| Qwen3.5 2B | `qwen3_5_2b_decode_int8lin` | 2.4 GB | Better plans, slower; first load pays a one-time GPU specialization. |
| LFM2.5 1.2B | `lfm2_5_1_2b_instruct_decode_int8lin` | 1.2 GB | Liquid AI instruct model. Non-thinking, snappy. |
| Granite 4.0-H 1B | `granite_4_0_h_1b_decode_int8lin` | 1.0 GB | IBM hybrid SSM (Mamba2 + attention). |

The zoo entries are Core AI `.aimodel` LanguageBundles from
[coreai-model-zoo](https://github.com/john-rocky/coreai-model-zoo), loaded with
`CoreAILanguageModel(resourcesAt:)` and driven through the *same*
`LanguageModelSession` API as Apple's own model. That is what makes the model a
one-line choice in this app: `CoreAITextSessionProvider` hands back a session and
the engine never learns which model it is talking to.

The one place the difference shows is structure. Apple's model gets
`@Generable` / `@Guide` schemas — `StreamBotPlanSchema`, `StreamBotRoutineSchema`,
`StreamBotMemorySchema` — and cannot return a malformed plan. Zoo models are asked
for one item per line and parsed, because guided generation is not available
behind them.

The bundles are fetched from the Models tab — tap a model, or its **Get** button,
and `ModelDownloader` streams the tree from Hugging Face into a staging directory,
renaming it into place only once every file is there. A half-present bundle
poisons Core AI's content-keyed cache, so the download is all-or-nothing. When it
lands, that model becomes the team's thinking model, because nobody downloads a
gigabyte and then goes looking for the row again.

Two sessions are opened per run over the same loaded model: one for the calls that
have a shape (the plan, the routine, the memory) and one for the prose the user
reads. A transcript is a habit — after a guided call, a small model asked for a
paragraph in the same session will answer in JSON, and it ends up in the thread.

### Speech — `SpeechTranscriber`

`StreamBotVoiceDictation` runs Apple's on-device speech stack:

```
mic (AVAudioEngine tap) → AsyncStream<AnalyzerInput> → SpeechAnalyzer
    → SpeechTranscriber.results → volatile + finalized text → composer draft
```

The locale's model is installed on demand through `AssetInventory` on first use.
That is a multi-hundred-megabyte download, so it is surfaced as a real phase
("Downloading the speech model") rather than a spinner — otherwise the first tap
of the mic looks broken for a minute.

### Cost control

A run is one planning call, one call per step, and one synthesis. Steps are capped
at four and step notes at 48 tokens, because the point is that you watch it
happen; a nine-step plan on a 1 B model is a progress bar with extra words.

---

## 3. How it works

```
you type or dictate
        │
        ▼
Stream message (your client)
        │  MessageNewEvent
        ▼
StreamBotMessageWatcher ── one-to-one thread ─→ StreamBotEngine.start(bot:)
        └──────────────── room, no mention ──→ StreamBotEngine.route(lead: Nova)
                                                        │
                        ┌───────────────────────────────┴────────────┐
                        ▼                                            ▼
             CoreAITextSessionProvider                        StreamBotSender
             (Apple FM or a Core AI zoo bundle)               (a ChatClient per bot)
                        │                                            │
              plan → steps → synthesis                    run card + streamed reply,
                        │                                 authored by the bot itself
                        └────────── StreamBotStore ◄──────────────────┘
                                (routines, memory, instructions — on device)
```

### How a plugin reaches a run

Three touch points, all in `StreamBotEngine.start`:

1. **Skills go into the instructions.** The skill matching the request — by an
   explicit `/Name` in the message, else by word overlap against its trigger, the
   same cheap and inspectable match the routines use — is appended to the system
   prompt for that run only.
2. **Connectors become tools on the writing session.** Only the writing session:
   planning is deciding what to do, and reading the calendar to decide it would
   pay for a tool call before the plan exists. The step that needs the data is the
   one that fetches it.
3. **The step is credited afterwards.** Each tool records itself in
   `StreamBotToolLog`; the engine drains the log after every step and re-tags that
   step with the surface the bot really visited. A tool call is otherwise invisible
   — it happens inside `respond`, between the prompt and the answer — and invisible
   work is exactly what the run card exists to prevent.

The system prompt otherwise tells a bot it has no access to anything, which is
why the connectors are then named explicitly: a model told it cannot reach the
calendar will talk itself out of calling a calendar tool it does have.

### Two kinds of Stream client

A bot's reply has to arrive as an incoming message from that bot — its name, its
avatar, its colour, on the left of the thread — or the "teammate" idea collapses
into you talking to yourself. Stream models that correctly: the message is
authored by the bot user, which means a connection authenticated as the bot.

* `StreamBotChatService` owns **your** client and installs the appearance.
* `StreamBotSender` owns a thin `ChatClient` **per bot** (local storage off, at
  most four connected at a time, LRU-evicted along with its cached message
  controllers).

Server-side sends with the API secret are not an option for an app that ships no
backend, and the secret must never be in the bundle. `StreamBotCredentials` holds
the public API key and CLI-minted user JWTs only.

### Streaming a reply through a chat backend

Chat has no token stream, so streaming is: send one message flagged
`grok_streaming`, edit it as tokens land (throttled), then clear the flag on the
last write. The view factory renders a flagged message with a caret and no
animation on the glyphs, so words appear as they are written instead of the
paragraph cross-fading on every token. Terminal writes get a second attempt — a
dropped mid-stream edit costs nothing, but a card left saying "Planning" after the
run is over is worse than a slow one.

### Where state lives

| State | Home | Why |
| --- | --- | --- |
| Roster: name, lane, accent, symbol, tagline, approval | Stream user custom data | Shared; every device sees the same team |
| Run: title, steps, status, progress, result | Message `extraData` (`grok_run`) | The card *is* the message, so history replays exactly |
| Message role: run card, reply, handoff, routine note | Message `extraData` (`grok_kind`) | Lets the view factory pick a renderer without guessing |
| Routines, memory, standing instructions | JSON in the app container (`StreamBotStore`) | Your working habits, distilled from your own messages, stay on your phone. Scheduled hour and last fire live on the routine. |
| Which plugins are added, and per-bot switches | JSON in the app container (`StreamBotPluginStore`) | Access granted on this phone should not follow the account to another device |
| Which model thinks | `AIModelPreferences` | Shared with the other Core AI demos in this project |
| Haptics, notifications, muted bots, schedule timezone | `UserDefaults` (`StreamBotPreferences`) | Device-local; there is no cloud computer to sync them to |

Channels carry `bot_app: "owngrokbot"` and the thread list filters on it, so
StreamBot's threads never mix with the other Stream demos on the same app key.
Those wire values — `grok_*` keys, `grok-<lane>` user IDs, `grokbot-<lane>`
channel IDs, the `owngrokbot` marker — predate the rename and are deliberately
left alone: they are seeded data in Stream, not user-visible strings.

### The UI layer

`StreamBotViewFactory` is where Stream's chat becomes this app's. It overrides
message rendering (run cards, streamed replies, handoffs, routine notes), the
channel list row, avatars, both backgrounds, the channel header, the composer and
its accessory strip, the message actions, and both empty states.

Everything tappable is a `Button` with a native glass style (`.glass`,
`.glassProminent`, `.buttonBorderShape`) rather than a `.glassEffect()` wrapped
around a tap gesture, so the hit shape always matches the glass that is drawn.
`.glassEffect()` is reserved for surfaces that only display: cards, pills, status
strips, the run card. The tab bar minimises on scroll down so a thread stays
readable on a small phone. Team, Models, and Settings open with an editorial
header and uppercase section labels rather than a list that starts at the first
card.

### Colour

`#005fff` — `Color.streamBot` in `StreamBotGlass.swift` — is the app's one colour.
It tints the tab bar and inherits down to every glass control, drives Stream's
`accentPrimary` (send button, badges, links), fills outgoing bubbles with white
text, and is the base of the drifting backdrop behind the glass.

A teammate's accent is only ever allowed on that teammate — its avatar, its row,
its run card, its detail sheet — so colour in this app always means "this bot" and
never "this control". The palette has no purple or indigo; a bot seeded with an
accent the app no longer offers falls back to `#005fff`. Paid Media uses brown
and Product Performance a navy that is not the brand blue, so those two new
roles stay identifiable without reopening colours that were retired.

---

## 4. Running it

1. Point the app's entry at StreamBot. `GlassElementInteractive.swift`:

```swift
#if os(iOS)
StreamBotRootView()
#endif
```

2. Build for an iOS 27 destination. The target also builds for macOS, where
   StreamBot is compiled out — Stream Chat's SwiftUI views, the speech capture,
   and the glass chrome are all UIKit-backed.
3. Run on a device for the full experience. Apple Intelligence cannot run
   inference in the Simulator, so pick a Core AI zoo model in **Models** there;
   the app says as much instead of reporting the framework's bare `error -1`.
4. Dictation needs microphone and speech-recognition permission, and the first
   tap downloads the locale's speech model.
5. Notifications are off until you switch them on in Settings.

The Stream side is already seeded (nine bot users, their threads, the Ops Room
with Nova as `lead_bot`, and never-expiring bot tokens). Paid Media and Product
Performance are hireable from Team and are not in that seed. To reseed on another
app key, use the Stream CLI: `UpdateUsers` for the bots, `GetOrCreateChannel` per
thread with `bot_app: "owngrokbot"`, `UpdateChannelPartial` to set `lead_bot` on
the room, and `CreateToken` per bot.

---

## 5. Honest limits

* **The only tools are the plugins.** No browser, no email, no CRM. What a bot can
  genuinely reach is what the plugins give it: your calendar, reminders, contacts,
  threads, and the clock — read-only, on this device. Every other workspace on a
  bot is a *declared* surface: it tells the planner which system a step happens
  in, and the UI is explicit that nothing is signed into. Plans stay concrete
  without pretending.
* **Connectors need Apple Intelligence.** A zoo bundle will not emit a tool call,
  so those models get the skills half of a plugin and nothing else.
* **Bot tokens ship in the app.** Fine for a demo on a demo key; a production
  build would mint them server-side or send bot messages from a backend.
* **Scheduled routines are not 24/7.** They fire the next time the app is opened
  after their hour. There is no background agent computer.
* **Sharing has no share-extension target.** Other apps reach StreamBot through
  `streambot://handoff?text=…`, Open-in for text, or the clipboard button on Team.
* **Small models write small.** Four steps, short notes, and a synthesis. Pick
  Qwen3.5 2B when plan quality matters more than latency.
* **iOS only**, and iOS 27 at that: `SpeechAnalyzer`, Liquid Glass, and the
  current Stream SwiftUI styles are all load-bearing.

---

## 6. File map

| File | What is in it |
| --- | --- |
| `StreamBotRootView.swift` | App shell: Threads / Team / Models / Settings, client start-up, Models tab, share URL intake |
| `StreamBotTeammate.swift` | The teammate model: lane, approval policy, workspaces, accent, presets |
| `StreamBotRun.swift` | Run, step, and message-kind types; the `extraData` codecs |
| `StreamBotEngine.swift` | The runtime: plan, work, synthesise, approve, teach, route, reconnect |
| `StreamBotChatService.swift` | Credentials, your Stream client, per-bot sender clients |
| `StreamBotMessageWatcher.swift` | Turns your messages into runs; picks the recipient in a room |
| `StreamBotRoster.swift` | Loads the team from Stream, with the nine seeded presets as a fallback |
| `StreamBotStore.swift` | On-device routines (including schedule), memory, and standing instructions |
| `StreamBotPreferences.swift` | Haptics, notifications, muted bots, timezone; haptic helpers |
| `StreamBotNotifications.swift` | Local pings when a bot finishes, fails, or needs a yes |
| `StreamBotShareIntake.swift` | Inbound share / clipboard / URL scheme, and the handoff sheet |
| `StreamBotScheduler.swift` | Fires due scheduled routines when the app becomes active |
| `StreamBotSettingsView.swift` | Settings: haptics, notifications, timezone, runtime reconnect |
| `StreamBotPlugin.swift` | The plugin catalogue: skills, connectors, categories |
| `StreamBotPluginStore.swift` | What is added, which bot it is on for, and system permissions |
| `StreamBotPluginTools.swift` | The connectors as FoundationModels tools, and the use log |
| `StreamBotPluginsView.swift` | Marketplace / Yours, and a plugin's page |
| `StreamBotViewFactory.swift` | Every Stream UI override, plus the thread screen and intro |
| `StreamBotRunCardView.swift` | The live plan card, its actions, and Share on a finished run |
| `StreamBotComposerAccessory.swift` | Dictation (record / review / send), run status strip, starter prompts |
| `StreamBotVoiceDictation.swift` | `SpeechAnalyzer` + `SpeechTranscriber` capture and levels |
| `StreamBotRosterView.swift` | Team grid, working/waiting chips, hire flow, clipboard handoff |
| `StreamBotDetailView.swift` | A bot's identity, policy, notifications, instructions, routines, memory |
| `StreamBotTeachCoordinator.swift` | The teach-as-routine flow and its banner |
| `StreamBotGlass.swift` | `#005fff`, the Stream appearance override, the glass primitives |
| `StreamBotInfo.plist` | `streambot://` URL scheme and text document types |
