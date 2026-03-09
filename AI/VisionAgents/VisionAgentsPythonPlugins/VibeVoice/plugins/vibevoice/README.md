# VibeVoice Text-to-Speech Plugin

A high-quality Text-to-Speech (TTS) plugin for [Vision Agents](https://visionagents.ai/) powered by Microsoft's [VibeVoice](https://github.com/microsoft/VibeVoice) — an open-source frontier voice AI framework for expressive, long-form, multi-speaker conversational audio.

## Features

- **Expressive speech**: Natural emotional nuances, spontaneous reactions, and even singing
- **Long-form generation**: Up to 90 minutes of continuous speech in a single pass (VibeVoice-1.5B)
- **Real-time streaming**: ~300 ms first-audible-speech latency (VibeVoice-Realtime-0.5B)
- **Multi-speaker support**: Up to 4 distinct speakers with natural turn-taking (VibeVoice-1.5B)
- **Multilingual**: English primary, with experimental support for 9 additional languages

## Installation

```bash
uv add "vision-agents[vibevoice]"
# or directly
uv add vision-agents-plugins-vibevoice
```

## Server Setup

The plugin connects to a running VibeVoice inference server. Start one before using the plugin:

```bash
# Clone VibeVoice
git clone https://github.com/microsoft/VibeVoice.git
cd VibeVoice
pip install -e .[streamingtts]

# Launch the real-time server
python demo/vibevoice_realtime_demo.py \
    --model_path microsoft/VibeVoice-Realtime-0.5B \
    --port 3000
```

Or run on [Google Colab with a free T4 GPU](https://colab.research.google.com/github/microsoft/VibeVoice/blob/main/demo/vibevoice_realtime_colab.ipynb).

## Usage

```python
from vision_agents.plugins import vibevoice

# Initialize — reads VIBEVOICE_BASE_URL from env (default: http://localhost:3000)
tts = vibevoice.TTS()

# Or configure explicitly
tts = vibevoice.TTS(
    base_url="http://localhost:3000",
    voice="en-Carter_man",
    cfg_scale=1.5,
    inference_steps=5,
)
```

### Use with an Agent

```python
from vision_agents.core import Agent
from vision_agents.plugins import getstream, openai, vibevoice

agent = Agent(
    edge=getstream.Edge(),
    tts=vibevoice.TTS(voice="en-Carter_man"),
    llm=openai.LLM(model="gpt-4o"),
)
```

### Query Available Voices

```python
voices = await tts.get_available_voices()
print(voices)
# ['en-Carter_man', 'en-Wayne_man', 'de-German_voice', ...]
```

## Parameters

| Name | Type | Default | Description |
|---|---|---|---|
| `base_url` | `str` or `None` | `None` | HTTP base URL of the VibeVoice server. Falls back to `VIBEVOICE_BASE_URL` env var, then `http://localhost:3000`. |
| `voice` | `str` or `None` | `None` | Speaker voice preset name. When `None`, the server default is used. |
| `cfg_scale` | `float` | `1.5` | Classifier-Free Guidance scale — higher values increase text adherence. |
| `inference_steps` | `int` or `None` | `None` | Diffusion inference steps. `None` uses the server default (typically 5). |
| `sample_rate` | `int` | `24000` | Output sample rate in Hz (must match the VibeVoice model). |

## Available Voices

Use the `voice` parameter or query the server at runtime with `await tts.get_available_voices()`.

### English

| Voice ID | Gender |
|---|---|
| `en-Carter_man` | Male (server default) |
| `en-Davis_man` | Male |
| `en-Frank_man` | Male |
| `en-Mike_man` | Male |
| `en-Emma_woman` | Female |
| `en-Grace_woman` | Female |
| `in-Samuel_man` | Male (Indian English) |

### Multilingual (experimental)

| Voice ID | Language | Gender |
|---|---|---|
| `de-Spk0_man` / `de-Spk1_woman` | German | Male / Female |
| `fr-Spk0_man` / `fr-Spk1_woman` | French | Male / Female |
| `it-Spk0_woman` / `it-Spk1_man` | Italian | Female / Male |
| `jp-Spk0_man` / `jp-Spk1_woman` | Japanese | Male / Female |
| `kr-Spk0_woman` / `kr-Spk1_man` | Korean | Female / Male |
| `nl-Spk0_man` / `nl-Spk1_woman` | Dutch | Male / Female |
| `pl-Spk0_man` / `pl-Spk1_woman` | Polish | Male / Female |
| `pt-Spk0_woman` / `pt-Spk1_man` | Portuguese | Female / Male |
| `sp-Spk0_woman` / `sp-Spk1_man` | Spanish | Female / Male |

25 voices total — 7 English + 18 multilingual across 9 languages. Multilingual voices are experimental; best results are with English.

## Environment Variables

| Variable | Description |
|---|---|
| `VIBEVOICE_BASE_URL` | Base URL of the VibeVoice server (e.g. `http://localhost:3000`) |
| `STREAM_API_KEY` | Stream API key for the Vision Agents edge transport |
| `STREAM_API_SECRET` | Stream API secret |

## Examples

The `examples/` directory contains three demo scripts showcasing VibeVoice's capabilities:

### Spontaneous Emotion

Expressive storytelling with natural emotional cues — laughter, surprise, empathy.

```bash
python examples/spontaneous_emotion.py
```

### Spontaneous Singing

Seamless transitions between speech and spontaneous singing/humming.

```bash
python examples/spontaneous_singing.py
```

### Podcast with Background Music

Long-form podcast-style dialogue with a charismatic AI host.

```bash
python examples/podcast_with_background_music.py
```

## API Reference

The plugin implements the standard Vision Agents TTS interface:

- `stream_audio(text)` — Connect to the VibeVoice WebSocket server and stream PCM audio chunks
- `stop_audio()` — Signal the streaming loop to stop
- `close()` — Tear down HTTP and WebSocket connections
- `send(text)` — Send text for synthesis (inherited from base class)
- `get_available_voices()` — Query the server for available voice presets

## Architecture

```
┌─────────────────┐     WebSocket      ┌──────────────────────┐
│  Vision Agents  │ ──── /stream ────▶ │  VibeVoice Server    │
│  TTS Plugin     │ ◀── PCM S16 ───── │  (Realtime-0.5B /    │
│                 │     24 kHz         │   1.5B multi-speaker)│
└─────────────────┘                    └──────────────────────┘
```

The plugin connects to the VibeVoice server's WebSocket endpoint (`/stream`), passing the text and generation parameters as query parameters. The server streams back raw PCM S16 audio at 24 kHz which the plugin wraps in `PcmData` objects for the Vision Agents framework.

## Troubleshooting

### `[Errno 61] Connect call failed ('127.0.0.1', 3000)`

The VibeVoice inference server isn't running. Start it in a separate terminal:

```bash
cd /path/to/VibeVoice
python demo/vibevoice_realtime_demo.py \
    --model_path microsoft/VibeVoice-Realtime-0.5B \
    --device mps --port 3000
```

Wait for `Uvicorn running on 0.0.0.0:3000` before running your agent.

If you don't have a local GPU, use the [Colab notebook](https://colab.research.google.com/github/microsoft/VibeVoice/blob/main/demo/vibevoice_realtime_colab.ipynb) and set the public URL:

```bash
export VIBEVOICE_BASE_URL=https://your-id.trycloudflare.com
```

### `ImportError: cannot import name 'ChannelMember'`

Version mismatch between `getstream` SDK and `vision-agents-plugins-getstream`. Pin to a compatible version:

```bash
uv pip install "getstream<3.0.0"
```

Or add `"getstream<3.0.0"` to your project's `dependencies` in `pyproject.toml` and run `uv lock && uv sync`.

### `ImportError: cannot import name 'vibevoice'`

The plugin isn't installed in your active virtual environment. Install it:

```bash
# From the project root
uv pip install -e plugins/vibevoice
```

### `ImportError: cannot import name 'getstream'` / `'openai'` / `'deepgram'`

The example plugin dependencies aren't installed. Run with the `examples` extra:

```bash
cd plugins/vibevoice
uv run --extra examples python examples/podcast_with_background_music.py run
```

### `zsh: no matches found: .[streamingtts]`

Zsh interprets square brackets as glob patterns. Wrap in quotes:

```bash
pip install -e ".[streamingtts]"
```

### `Conversation ID cannot be used for this organization due to Zero Data Retention`

Your OpenAI organization has Zero Data Retention enabled, which is incompatible with `openai.LLM` (Responses API). Use the Chat Completions API instead:

```python
# Instead of:
llm=openai.LLM(model="gpt-4o")

# Use:
llm=openai.ChatCompletionsLLM(model="gpt-4o")
```

### `Service busy` / WebSocket returns `1013`

The VibeVoice server handles one request at a time. Wait for the current synthesis to finish before sending another request. If the server is stuck, restart it.

### No audio but no errors

- Verify the VibeVoice server is reachable: `curl http://localhost:3000/config`
- Check that your voice preset exists: the server returns available voices at `/config`
- Ensure `sample_rate` matches the model (24000 for Realtime-0.5B)

### Mac MPS performance issues

If speech generation is too slow on Mac:

- Use `--device mps` (not `cpu`) when starting the server
- Mac M4 Pro or newer is recommended for real-time performance
- Reduce `inference_steps` for faster (but lower quality) output:
  ```python
  tts = vibevoice.TTS(inference_steps=3)
  ```

## Requirements

- Python 3.10+
- A running VibeVoice inference server (GPU recommended)
- `websockets>=12.0`
- `httpx>=0.27.0`

## Links

- [VibeVoice GitHub](https://github.com/microsoft/VibeVoice)
- [VibeVoice-Realtime-0.5B on Hugging Face](https://huggingface.co/microsoft/VibeVoice-Realtime-0.5B)
- [VibeVoice-1.5B on Hugging Face](https://huggingface.co/microsoft/VibeVoice-1.5B)
- [Vision Agents Documentation](https://visionagents.ai/)
- [Plugin Creation Guide](https://visionagents.ai/integrations/create-your-own-plugin)
