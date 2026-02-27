# Lyria Plugin for Vision Agents

Google Lyria 3 music generation integration for the Vision Agents framework, enabling AI-powered instrumental music creation from voice prompts.

Features:
- Generate 30-second instrumental music tracks from text prompts
- Real-time streaming of generated audio to the call
- Dynamic style control with weighted prompts, BPM, density, and brightness
- Save generated tracks as WAV files
- Function calling support for LLM-driven music generation

## Installation

```bash
uv add "vision-agents[lyria]"
```

Or install the `google-genai` SDK directly:

```bash
pip install "google-genai>=1.16.0"
```

## Usage

### Basic Agent Setup

```python
from vision_agents.core import User, Agent
from vision_agents.plugins import getstream, openai, deepgram, elevenlabs, lyria

processor = lyria.MusicProcessor(
    initial_prompt="Lo-fi hip hop beats",
    bpm=85,
    duration_seconds=30,
)

llm = openai.LLM("gpt-4o-mini")

agent = Agent(
    edge=getstream.Edge(),
    agent_user=User(name="Music AI"),
    instructions="You are a music-generating assistant. When users ask for music, use the generate_music function.",
    llm=llm,
    stt=deepgram.STT(),
    tts=elevenlabs.TTS(),
    processors=[processor],
)

@llm.register_function(description="Generate music based on a text prompt")
async def generate_music(prompt: str) -> str:
    path = await processor.generate_music(prompt=prompt)
    return f"Music generated and saved to {path}"

@llm.register_function(description="Change the music style")
async def change_style(prompt: str) -> str:
    await processor.update_prompt(prompt)
    return f"Style changed to: {prompt}"
```

### Standalone Music Generation

```python
import asyncio
from vision_agents.plugins.lyria import MusicProcessor

async def main():
    processor = MusicProcessor(
        initial_prompt="Ambient chill",
        bpm=90,
        duration_seconds=30,
    )

    output_path = await processor.generate_music(
        prompt="Epic cinematic orchestral music"
    )
    print(f"Music saved to: {output_path}")

    await processor.close()

asyncio.run(main())
```

### Weighted Prompts (Blending Styles)

```python
await processor.set_weighted_prompts([
    {"text": "Jazz", "weight": 0.7},
    {"text": "Electronic", "weight": 0.3},
    {"text": "Chill", "weight": 0.5},
])

output = await processor.generate_music()
```

## Configuration

The plugin requires a Google API key. Provide it in one of two ways:

1. Set the environment variable `GOOGLE_API_KEY`
2. Pass it directly: `MusicProcessor(api_key="...")`

### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `initial_prompt` | `str` | `"Ambient chill music"` | Music style/genre prompt |
| `bpm` | `int` | `90` | Beats per minute (40-180) |
| `density` | `float` | `0.5` | Note density (0.0-1.0) |
| `brightness` | `float` | `0.5` | Tonal brightness (0.0-1.0) |
| `guidance` | `float` | `4.0` | Prompt adherence (0.0-6.0) |
| `scale` | `str` | `None` | Musical scale (e.g., `"C_MAJOR_A_MINOR"`) |
| `duration_seconds` | `int` | `30` | Duration of generated music |
| `output_dir` | `str` | `"generated_music"` | Directory for WAV output |
| `api_key` | `str` | `None` | Google API key (defaults to `GOOGLE_API_KEY` env var) |

## Events

| Event | Description |
|-------|-------------|
| `LyriaMusicGenerationStartedEvent` | Music generation begins |
| `LyriaMusicGenerationChunkEvent` | Each audio chunk received |
| `LyriaMusicGenerationCompletedEvent` | Generation completed with output path |
| `LyriaMusicGenerationErrorEvent` | Generation encountered an error |
| `LyriaPromptChangedEvent` | Style prompt was updated |
| `LyriaConnectionStateEvent` | WebSocket connection state changed |

## Prompting Tips

- Keep prompts concise: `"meditation"`, `"jazz piano"`, `"epic orchestral"`
- Combine genre + instrument + mood: `"Indie Pop, Sitar, Danceable"`
- Use weighted prompts for blending: `"Piano:2.0, Meditation:0.5"`
- The model is instrumental-only (no lyrics)
- Allow ~5-10 seconds for the model to settle into a groove

## Links

- [Vision Agents Documentation](https://visionagents.ai/)
- [Lyria RealTime API](https://ai.google.dev/gemini-api/docs/music-generation)
- [GitHub](https://github.com/GetStream/Vision-Agents)
