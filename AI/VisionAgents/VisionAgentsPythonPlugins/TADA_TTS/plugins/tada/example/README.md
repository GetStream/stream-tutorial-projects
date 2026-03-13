# TADA TTS Example

This example demonstrates using TADA TTS with Vision Agents for real-time voice AI.

## Prerequisites

- CUDA-capable GPU (TADA runs locally)
- Python 3.10+

## Environment Variables

```bash
export DEEPGRAM_API_KEY="your_deepgram_key"
export GOOGLE_API_KEY="your_google_key"
export STREAM_API_KEY="your_stream_key"
export STREAM_API_SECRET="your_stream_secret"
```

## Running

```bash
cd plugins/tada/example
uv sync
uv run python tada_example.py
```
