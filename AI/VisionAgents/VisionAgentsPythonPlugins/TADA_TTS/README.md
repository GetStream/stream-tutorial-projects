# TADA TTS Plugin for Vision Agents

A custom [Vision Agents](https://github.com/GetStream/Vision-Agents) TTS plugin that integrates [TADA](https://github.com/HumeAI/tada) (Text-Acoustic Dual Alignment) by [Hume AI](https://hume.ai) for high-quality, local text-to-speech synthesis.

## What is TADA?

TADA is an open-source speech language model that synchronizes text and speech into a single stream via 1:1 alignment. Key highlights:

- **Fast**: ~0.09 real-time factor (5x faster than comparable LLM-based TTS)
- **Reliable**: Zero hallucinations by construction
- **Expressive**: Dynamic duration and prosody per token
- **Voice Cloning**: Clone any voice from a short reference audio clip
- **Multilingual**: Supports 10 languages (with the 3B model)
- **Local**: Runs entirely on your GPU, no API keys needed for TTS

## Project Structure

```
TADA_TTS/
├── main.py                              # Entry point with Vision Agents pipeline
├── pyproject.toml                       # Project dependencies
├── plugins/
│   └── tada/
│       ├── pyproject.toml               # Plugin package config
│       ├── README.md                    # Plugin documentation
│       ├── py.typed                     # PEP 561 type marker
│       ├── vision_agents/
│       │   └── plugins/
│       │       └── tada/
│       │           ├── __init__.py      # Public exports
│       │           └── tts.py           # TTS implementation
│       ├── example/
│       │   ├── tada_example.py          # Standalone example
│       │   └── pyproject.toml           # Example dependencies
│       └── tests/
│           └── test_tts.py              # Integration tests
```

## Quick Start

### 1. Install Dependencies

```bash
uv sync
```

### 2. Set Environment Variables

```bash
export DEEPGRAM_API_KEY="your_deepgram_key"
export GOOGLE_API_KEY="your_google_key"
export STREAM_API_KEY="your_stream_key"
export STREAM_API_SECRET="your_stream_secret"
```

### 3. Run the Agent

```bash
uv run python main.py
```

## Plugin Usage

```python
from vision_agents.plugins import tada

# Default (3B multilingual model, built-in voice)
tts = tada.TTS()

# English-only 1B model
tts = tada.TTS(model="HumeAI/tada-1b")

# Voice cloning
tts = tada.TTS(
    voice="path/to/reference.wav",
    voice_transcript="Transcript of the reference audio.",
)

# Multilingual (German)
tts = tada.TTS(
    model="HumeAI/tada-3b-ml",
    language="de",
)
```

## Requirements

- Python 3.10+
- CUDA-capable GPU (for TADA inference)
- [Stream](https://getstream.io/try-for-free/) account (for real-time transport)
