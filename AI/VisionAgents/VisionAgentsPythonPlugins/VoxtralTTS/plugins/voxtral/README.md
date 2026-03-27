# Voxtral TTS Plugin

A Text-to-Speech (TTS) plugin for [Vision Agents](https://github.com/GetStream/Vision-Agents) powered by Mistral's [Voxtral TTS](https://mistral.ai/news/voxtral-tts) model. Features zero-shot voice cloning, multilingual support, and low-latency streaming.

## Features

- Zero-shot voice cloning from 2-3 seconds of audio
- 9 languages: English, French, Spanish, Portuguese, Italian, Dutch, German, Hindi, Arabic
- Low-latency streaming (~0.7s time-to-first-audio with PCM)
- Cross-lingual voice adaptation
- Emotionally expressive speech generation

## Installation

```bash
uv add "vision-agents[voxtral]"
# or directly
uv add vision-agents-plugins-voxtral
```

## Usage

### Basic Usage with a Saved Voice

```python
from vision_agents.plugins import voxtral

# Use a previously created voice by ID
tts = voxtral.TTS(voice_id="your-voice-id")
```

### Zero-Shot Voice Cloning

```python
import base64
from pathlib import Path
from vision_agents.plugins import voxtral

# Clone a voice on-the-fly from a reference audio clip
ref_audio = base64.b64encode(Path("sample.mp3").read_bytes()).decode()
tts = voxtral.TTS(ref_audio=ref_audio)
```

### Full Agent Example

```python
from vision_agents.plugins import voxtral, deepgram, gemini, getstream

agent = Agent(
    edge=getstream.Edge(),
    tts=voxtral.TTS(voice_id="your-voice-id"),
    stt=deepgram.STT(),
    llm=gemini.LLM(),
)
```

## Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `api_key` | `str` | `MISTRAL_API_KEY` env var | Mistral API key |
| `model` | `str` | `"voxtral-mini-tts-2603"` | Model identifier |
| `voice_id` | `str` | `None` | Saved voice ID for consistent voice reuse |
| `ref_audio` | `str` | `None` | Base64-encoded audio for zero-shot voice cloning |
| `response_format` | `str` | `"pcm"` | Audio format: `"pcm"`, `"mp3"`, `"wav"`, `"opus"`, `"flac"` |

## Voice Cloning Guidelines

When using `ref_audio` for zero-shot cloning:

- **Duration**: 3-25 seconds of audio
- **Speaker**: Single speaker only
- **Quality**: Clean recording with no background noise
- **Prosody**: Neutral — avoid excessive pausing or disfluencies
- **Pitch**: Expressive pitch produces better results (flat voices produce flat output)

## Supported Audio Formats

| Format | Description | Best For |
|--------|-------------|----------|
| `pcm` | Raw float32 LE samples | Streaming (lowest latency ~0.7s TTFA) |
| `mp3` | Compressed | General use |
| `wav` | Uncompressed PCM | Highest quality |
| `opus` | Low bitrate | Streaming |
| `flac` | Lossless compression | Archival |

## Requirements

- Python 3.10+
- mistralai>=1.0.0
- A Mistral API key ([get one here](https://console.mistral.ai/))
