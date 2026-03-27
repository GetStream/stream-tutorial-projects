# Voxtral TTS Examples

This directory contains examples demonstrating how to use the Voxtral TTS plugin with Vision Agents.

## Examples

### 1. Basic Agent Example (`voxtral_example.py`)

Complete agent setup with Voxtral TTS, Deepgram STT, Gemini LLM, and real-time communication via GetStream.

### 2. Voice Cloning Example (`voxtral_voice_cloning_example.py`)

Demonstrates zero-shot voice cloning with two approaches:
- **On-the-fly cloning**: Pass a base64-encoded audio clip via `ref_audio`
- **Saved voice**: Create a reusable voice via the Mistral Voices API and reference it by `voice_id`

## Setup

1. Install dependencies:

```bash
cd plugins/voxtral/example
uv sync
```

2. Create a `.env` file with your API keys:

```bash
MISTRAL_API_KEY=your_mistral_api_key
DEEPGRAM_API_KEY=your_deepgram_api_key
GOOGLE_API_KEY=your_google_api_key
STREAM_API_KEY=your_stream_api_key
STREAM_API_SECRET=your_stream_api_secret
```

3. For voice cloning, place a reference audio file named `sample.mp3` in the example directory (3-25 seconds, single speaker, clean recording).

## Running the Examples

### Basic Agent

```bash
uv run voxtral_example.py run
```

### Voice Cloning (with ref_audio)

```bash
uv run voxtral_voice_cloning_example.py run
```

## Voice Cloning Guidelines

For best results with `ref_audio`:

- **Duration**: 3-25 seconds
- **Speaker**: Single speaker only
- **Quality**: Clean recording, no background noise
- **Prosody**: Neutral — avoid excessive pausing or disfluencies
- **Pitch**: Expressive pitch works better (flat voices produce flat output)

## Additional Resources

- [Voxtral TTS Documentation](https://docs.mistral.ai/capabilities/audio/text_to_speech)
- [Mistral Voices API](https://docs.mistral.ai/capabilities/audio/text_to_speech/voices)
- [Vision Agents Documentation](https://visionagents.ai)
