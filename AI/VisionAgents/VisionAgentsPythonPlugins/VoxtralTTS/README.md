# Voxtral TTS Plugin for Vision Agents

A [Vision Agents](https://visionagents.ai/) plugin that integrates [Voxtral TTS](https://docs.mistral.ai/capabilities/voice/) (Mistral's text-to-speech model) for real-time voice AI agents on [Stream](https://getstream.io/).

Voxtral TTS delivers multilingual speech synthesis with **zero-shot voice cloning** — clone any voice from a short audio clip, capturing emotion, speaking style, and accent.

## Features

- **Zero-shot voice cloning** — clone a voice from as little as 3 seconds of audio
- **9 languages** — English, French, Spanish, Portuguese, Italian, Dutch, German, Hindi, and Arabic
- **Low-latency streaming** — ~0.7s time-to-first-audio with PCM output
- **Saved voices** — create reusable voices via the Mistral Voices API
- **Multiple output formats** — PCM, MP3, WAV, Opus, FLAC

## Prerequisites

- Python 3.10+
- A [Mistral API key](https://console.mistral.ai/)
- A [Deepgram API key](https://deepgram.com/) (for speech-to-text)
- A [Google API key](https://aistudio.google.com/) (for Gemini LLM)
- [Stream API credentials](https://getstream.io/try-for-free/) (for real-time communication)

## Setup

1. **Install dependencies**

```bash
cd plugins/voxtral/example
python -m venv .venv
source .venv/bin/activate
pip install -e ..
```

2. **Configure environment variables**

Copy the example and fill in your keys:

```bash
cp .env.example .env
```

```
STREAM_API_KEY=your_stream_api_key
STREAM_API_SECRET=your_stream_api_secret
EXAMPLE_BASE_URL=https://demo.visionagents.ai

MISTRAL_API_KEY=your_mistral_api_key
DEEPGRAM_API_KEY=your_deepgram_api_key
GOOGLE_API_KEY=your_google_api_key
```

## Usage

### Basic Example

Run a multilingual voice assistant with on-the-fly voice cloning from a reference audio file:

```bash
python plugins/voxtral/example/voxtral_example.py
```

This creates an agent that:
- Clones a voice from `david.wav` using `ref_audio`
- Uses Deepgram for speech-to-text
- Uses Gemini as the LLM
- Joins a Stream video call and responds with the cloned voice

### Voice Cloning Example

Demonstrates both voice cloning approaches:

```bash
python plugins/voxtral/example/voxtral_voice_cloning_example.py
```

**Approach 1 — On-the-fly cloning with `ref_audio`**

Pass a base64-encoded audio clip directly. Best for one-off use or experimentation:

```python
from vision_agents.plugins.voxtral import TTS as VoxtralTTS

tts = VoxtralTTS(
    model="voxtral-mini-tts-2603",
    ref_audio=base64_encoded_audio,
    response_format="pcm",
)
```

**Approach 2 — Saved voice with `voice_id`**

Create a persistent voice via the Mistral Voices API, then reuse it across requests:

```python
from mistralai.client import Mistral

client = Mistral(api_key="your_key")
voice = client.audio.voices.create(
    name="my-cloned-voice",
    sample_audio=base64_encoded_audio,
    sample_filename="sample.wav",
    languages=["en"],
)

tts = VoxtralTTS(
    model="voxtral-mini-tts-2603",
    voice_id=voice.id,
    response_format="pcm",
)
```

## Reference Audio Tips

For best voice cloning results:
- Use **3–25 seconds** of clean audio
- Single speaker only, no background noise
- WAV or MP3 format
- Natural, conversational speech works best

## Project Structure

```
VoxtralTTS/
├── .env.example
├── README.md
└── plugins/voxtral/
    ├── pyproject.toml
    ├── vision_agents/plugins/voxtral/
    │   ├── __init__.py
    │   └── tts.py                         # TTS implementation
    └── example/
        ├── voxtral_example.py             # Basic usage
        └── voxtral_voice_cloning_example.py  # Voice cloning demo
```

## Resources

- [Voxtral TTS Documentation](https://docs.mistral.ai/capabilities/voice/)
- [Vision Agents](https://visionagents.ai/)
- [Stream Video & Audio](https://getstream.io/video/)
- [Sign up for Stream (free)](https://getstream.io/try-for-free/)
