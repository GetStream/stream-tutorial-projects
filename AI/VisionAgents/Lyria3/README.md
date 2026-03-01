# Lyria 3 AI Music Generator

Generate classical, instrumental, afrobeats, retro synthwave, pop, rock, jazz, R&B, folk, 80s, 90s, etc music using [Google Lyria RealTime](https://ai.google.dev/gemini-api/docs/music-generation) in the Gemini API. Lyria 3 uses a streaming, WebSocket-based model that produces 48kHz stereo PCM audio in real time.

The GitHub demos in this project include standalone scripts using the model in the Gemini API for quick experimentation. There are also [Vision Agents](https://visionagents.ai/) plugin examples that let users generate music through voice commands in live audio and video calls using the Gemini Live API.

## Prerequisites & Setup

- Python 3.13+
- [uv](https://docs.astral.sh/uv/) package manager
- A [Google API key](https://aistudio.google.com/apikey) with Gemini API access

```bash
# Clone and enter the project
cd Lyria3

# Create a .env file with your API keys
echo "GOOGLE_API_KEY=your-key-here" > .env

# For the Vision Agents plugin (video call + phone call), also add:
# STREAM_API_KEY=your-stream-key
# STREAM_API_SECRET=your-stream-secret

# For Twilio phone call support, also add:
# TWILIO_ACCOUNT_SID=your-twilio-sid
# TWILIO_AUTH_TOKEN=your-twilio-token

# Install dependencies
uv sync
```

## Standalone Scripts Using Gemini API

Three self-contained scripts demonstrate Lyria RealTime capabilities. Each generates a 30-second WAV file and auto-plays it on completion.

### Quick Start — Basic Generation

Generate minimal techno at 90 BPM with a single prompt.

```bash
uv run music_gen_quick_start.py
```

**Output:** `generated_music/quick_start_minimal_techno_90bpm.wav`

### Steer Prompts in Real Time

Start with minimal techno, then midway through switch to a blend of Piano (weight 2.0), Meditation (0.5), and Live Performance (1.0). Lyria transitions smoothly between styles.

```bash
uv run music_gen_altered.py
```

**Output:** `generated_music/altered_techno_to_piano_meditation_90bpm.wav`

### Update Configuration in Real Time

Start at 90 BPM, then midway through change to 128 BPM in D major/B minor with QUALITY mode. Uses `reset_context()` for BPM and scale changes as required by the API.

```bash
uv run music_gen_realtime_update.py
```

**Output:** `generated_music/realtime_update_90_to_128bpm.wav`

## Vision Agents Plugin

A full-featured plugin that integrates Lyria 3 with [Vision Agents](https://visionagents.ai/), enabling voice-controlled music generation in a live video call powered by Gemini Realtime.

### Run the Agent

```bash
uv run main.py run
```

A browser window opens with the Vision Agents demo UI. Speak to the agent to generate music:

- *"Generate an Afrobeat instrumental track"*
- *"Set the tempo to 120 BPM"*
- *"Change the style to Lo-Fi Hip Hop"*
- *"Blend Jazz and Electronic music"*

Generated WAV files are saved to the `generated_music/` directory and auto-play when complete.

### Available Voice Commands

| Command | Description |
|---|---|
| `generate_music` | Create a 30s instrumental track from a text prompt |
| `change_music_style` | Update the style for the next generation |
| `set_tempo` | Set BPM (range: 40–180) |
| `blend_styles` | Mix two styles with custom weights |

### Plugin Structure

```
plugins/lyria/
├── pyproject.toml
├── README.md
├── py.typed
├── example/
│   └── main.py
├── tests/
│   └── test_lyria_music_processor.py
└── vision_agents/plugins/lyria/
    ├── __init__.py
    ├── events.py
    ├── lyria_audio_track.py
    └── lyria_music_processor.py
```

## Music Generation via Phone Call

Generate music through a Twilio outbound phone call. The agent calls the specified number, greets the caller, and generates music based on voice requests — all over a regular phone line.

### Prerequisites

- A [Twilio](https://www.twilio.com/) account with an active phone number
- [ngrok](https://ngrok.com/) to expose your local server for Twilio's WebSocket media stream

### Run the Phone Call Agent

```bash
# Start ngrok in a separate terminal
ngrok http 8000

# Run the agent with your ngrok URL, Twilio number, and destination number
NGROK_URL=https://your-subdomain.ngrok-free.app uv run music_gen_via_phone_call.py \
  --from +1XXXXXXXXXX \
  --to +1XXXXXXXXXX
```

The agent will:

1. Start a local server on port 8000
2. Place an outbound call via Twilio to the `--to` number
3. Greet the caller and ask what music they'd like
4. Generate a 30-second track using Lyria 3 when requested
5. Auto-play the generated WAV file on the server

The same voice commands available in the video call agent (`generate_music`, `set_tempo`, `change_music_style`, `blend_styles`) work over the phone.

## Lyria RealTime Controls

| Parameter | Range | Description |
|---|---|---|
| `bpm` | 60–200 | Beats per minute (requires `reset_context()`) |
| `density` | 0.0–1.0 | Note density — higher is busier |
| `brightness` | 0.0–1.0 | Tonal brightness — higher emphasizes treble |
| `guidance` | 0.0–6.0 | Prompt adherence — higher follows prompts more closely |
| `temperature` | 0.0–3.0 | Audio variance — higher produces more variation |
| `scale` | Scale enum | Musical key (requires `reset_context()`) |
| `music_generation_mode` | QUALITY / DIVERSITY / VOCALIZATION | Generation focus |

## Prompting Tips

Lyria RealTime accepts descriptive text prompts covering:

- **Genres:** Afrobeat, Lo-Fi Hip Hop, Jazz Fusion, Minimal Techno, Bossa Nova, ...
- **Instruments:** Rhodes Piano, Sitar, TR-909 Drum Machine, Kalimba, Cello, ...
- **Moods:** Dreamy, Upbeat, Ethereal Ambience, Tight Groove, Chill, ...

Use `WeightedPrompt` to blend multiple styles. Weight values can be any non-zero float — `1.0` is a good starting point, higher values increase influence.

## Audio Specifications

- **Format:** Raw 16-bit PCM
- **Sample rate:** 48 kHz
- **Channels:** 2 (stereo)
- **Chunk size:** ~2 seconds

## Resources

- [Lyria RealTime Documentation](https://ai.google.dev/gemini-api/docs/music-generation)
- [Vision Agents Documentation](https://visionagents.ai/)
- [Prompt DJ on AI Studio](https://aistudio.google.com/app/live/new?model=lyria-realtime-exp)
- [Google GenAI Python SDK](https://pypi.org/project/google-genai/)
