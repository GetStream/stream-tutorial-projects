# Qwen3-TTS Plugin for Vision Agents

A [Vision Agents](https://visionagents.ai/) plugin that integrates [Qwen3-TTS](https://github.com/QwenLM/Qwen3-TTS) (Alibaba Cloud's open-source TTS series) for real-time voice AI agents on [Stream](https://getstream.io/), powered by [HuggingFace Transformers](https://visionagents.ai/integrations/llm/huggingface-transformers).

Qwen3-TTS delivers multilingual speech synthesis across **10 languages** with three powerful generation modes: built-in custom voices, text-described voice design, and **zero-shot voice cloning** from just 3 seconds of audio.

## Features

- **9 built-in speakers** — Vivian, Serena, Uncle_Fu, Dylan, Eric, Ryan, Aiden, Ono_Anna, Sohee
- **10 languages** — Chinese, English, Japanese, Korean, German, French, Russian, Portuguese, Spanish, Italian
- **Instruction-controlled prosody** — control emotion, tone, and speaking style with natural language
- **Voice design** — create novel voices from text descriptions (e.g. "warm female narrator in her 30s")
- **Zero-shot voice cloning** — clone any voice from a 3-second audio clip
- **Streaming generation** — ultra-low-latency with first audio packet in ~97ms
- **Multiple model sizes** — 0.6B (lightweight) and 1.7B (full-featured)

## Models

| Model | HuggingFace ID | Mode | Parameters | Features |
|-------|---------------|------|------------|----------|
| **CustomVoice 1.7B** | `Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice` | `custom_voice` | 1.7B | 9 speakers + instruction control |
| **CustomVoice 0.6B** | `Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice` | `custom_voice` | 0.6B | 9 speakers (no instruction control) |
| **VoiceDesign 1.7B** | `Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign` | `voice_design` | 1.7B | Text-described voice design |
| **Base 1.7B** | `Qwen/Qwen3-TTS-12Hz-1.7B-Base` | `voice_clone` | 1.7B | Zero-shot voice cloning |
| **Base 0.6B** | `Qwen/Qwen3-TTS-12Hz-0.6B-Base` | `voice_clone` | 0.6B | Lightweight voice cloning |

## Prerequisites

- Python 3.10+
- A GPU with CUDA support (recommended) or Apple Silicon (MPS)
- A [HuggingFace account](https://huggingface.co/join) and access token (`HF_TOKEN`)
- A [Deepgram API key](https://deepgram.com/) (for speech-to-text)
- A [Google API key](https://aistudio.google.com/) (for Gemini LLM)
- [Stream API credentials](https://getstream.io/try-for-free/) (for real-time communication)

## Setup

1. **Install dependencies**

```bash
uv sync
```

2. **Configure environment variables**

Create a `.env` file with your keys:

```
STREAM_API_KEY=your_stream_api_key
STREAM_API_SECRET=your_stream_api_secret
EXAMPLE_BASE_URL=https://demo.visionagents.ai

HF_TOKEN=your_huggingface_token
DEEPGRAM_API_KEY=your_deepgram_api_key
GOOGLE_API_KEY=your_google_api_key
```

## Usage

### CustomVoice — Built-in Speakers with Style Control

```python
from plugins.qwen3tts.vision_agents.plugins.qwen3tts import TTS as Qwen3TTS

tts = Qwen3TTS(
    model="Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice",
    mode="custom_voice",
    speaker="Vivian",
    language="Auto",
    instruct="Speak in a warm, friendly tone.",
)
```

Available speakers: `Vivian`, `Serena`, `Uncle_Fu`, `Dylan`, `Eric`, `Ryan`, `Aiden`, `Ono_Anna`, `Sohee`

### VoiceDesign — Create Voices from Descriptions

```python
tts = Qwen3TTS(
    model="Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign",
    mode="voice_design",
    language="English",
    instruct="A warm, confident female narrator in her 30s with a clear mid-range voice.",
)
```

### Voice Clone — Clone Any Voice from Audio

```python
tts = Qwen3TTS(
    model="Qwen/Qwen3-TTS-12Hz-1.7B-Base",
    mode="voice_clone",
    language="English",
    ref_audio="path/to/reference.wav",
    ref_text="Transcript of the reference audio.",
)

# Pre-cache the clone prompt for faster subsequent calls
await tts.prepare_voice_clone_prompt()
```

### Full Agent Example

```python
from vision_agents.core import Agent, User
from vision_agents.plugins import deepgram, gemini, getstream, smart_turn
from plugins.qwen3tts.vision_agents.plugins.qwen3tts import TTS as Qwen3TTS

agent = Agent(
    edge=getstream.Edge(),
    agent_user=User(name="Qwen3 TTS AI", id="agent"),
    instructions="You are a helpful voice assistant.",
    tts=Qwen3TTS(
        model="Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice",
        mode="custom_voice",
        speaker="Ryan",
        language="English",
    ),
    stt=deepgram.STT(),
    llm=gemini.LLM("gemini-3.5-flash"),
    turn_detection=smart_turn.TurnDetection(),
)
```

## Examples

Each example targets a specific model from the Qwen3-TTS HuggingFace collection:

| Example | Model | Description |
|---------|-------|-------------|
| `custom_voice_1_7b_example.py` | 1.7B CustomVoice | 9 speakers + instruction control |
| `custom_voice_0_6b_example.py` | 0.6B CustomVoice | Lightweight, 9 speakers |
| `voice_design_example.py` | 1.7B VoiceDesign | Design a voice from text |
| `voice_clone_1_7b_example.py` | 1.7B Base | Zero-shot voice cloning |
| `voice_clone_0_6b_example.py` | 0.6B Base | Lightweight voice cloning |

Run any example:

```bash
uv run python plugins/qwen3tts/example/custom_voice_1_7b_example.py
```

## TTS Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `model` | `str` | `Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice` | HuggingFace model ID |
| `mode` | `str` | `custom_voice` | `"custom_voice"`, `"voice_design"`, or `"voice_clone"` |
| `speaker` | `str` | `Vivian` | Speaker name (custom_voice mode only) |
| `language` | `str` | `Auto` | Target language or `"Auto"` for auto-detection |
| `instruct` | `str` | `None` | Natural-language style instruction |
| `ref_audio` | `str` | `None` | Reference audio path/URL/base64 (voice_clone mode) |
| `ref_text` | `str` | `None` | Transcript of reference audio (voice_clone mode) |
| `device` | `str` | `auto` | `"auto"`, `"cuda"`, `"mps"`, or `"cpu"` |
| `dtype` | `str` | `bfloat16` | `"bfloat16"`, `"float16"`, or `"float32"` |
| `attn_implementation` | `str` | `None` | `"flash_attention_2"`, `"sdpa"`, or `None` |

## Project Structure

```
Qwen3-TTS-HF/
├── main.py                              # Quick-start entry point
├── pyproject.toml
├── .env
└── plugins/qwen3tts/
    ├── pyproject.toml                   # Plugin package metadata
    ├── README.md                        # This file
    ├── py.typed
    ├── vision_agents/plugins/qwen3tts/
    │   ├── __init__.py
    │   └── tts.py                       # TTS implementation
    ├── example/
    │   ├── custom_voice_1_7b_example.py
    │   ├── custom_voice_0_6b_example.py
    │   ├── voice_design_example.py
    │   ├── voice_clone_1_7b_example.py
    │   └── voice_clone_0_6b_example.py
    └── tests/
        └── test_tts.py
```

## Limitations

### Hardware Requirements

- **CUDA GPU strongly recommended** — Qwen3-TTS is designed for NVIDIA GPUs. The 1.7B models require ~4 GB VRAM (bfloat16) and the 0.6B models require ~1.5 GB VRAM.
- **Apple Silicon (MPS) not directly supported** — the plugin falls back to CPU on macOS. Expect 5-15 seconds per utterance for the 0.6B model and 15-40+ seconds for the 1.7B model on CPU.
- **FlashAttention 2 requires CUDA** — the `attn_implementation="flash_attention_2"` option only works on NVIDIA GPUs with Ampere architecture or newer (RTX 30xx+). On other hardware, omit this parameter.

### Model-Specific Constraints

| Model | Limitation |
|-------|-----------|
| **CustomVoice 0.6B** | No instruction-based style control (`instruct` parameter is ignored). |
| **CustomVoice 1.7B** | Instruction control works best in Chinese and English; other languages may have reduced expressiveness. |
| **VoiceDesign 1.7B** | Only available in the 1.7B size. No 0.6B variant exists for voice design. |
| **Base 0.6B / 1.7B** | Voice cloning quality depends heavily on reference audio — use 3-25 seconds of clean, single-speaker audio with no background noise. |

### Generation Characteristics

- **Batch-only output** — the plugin generates complete audio in one pass and returns it as a single `PcmData` object. It does not stream audio token-by-token to the caller (though Qwen3-TTS supports streaming internally, the Vision Agents TTS interface expects a complete or iterable result).
- **First-call latency** — the first `stream_audio()` call downloads model weights from HuggingFace (~1.2 GB for 0.6B, ~3.4 GB for 1.7B) and loads them into memory. Subsequent calls reuse the loaded model.
- **No concurrent generation** — the plugin uses a `ThreadPoolExecutor` with 2 workers. Generation calls are serialized through the executor; overlapping requests will queue.
- **SoX optional dependency** — the `qwen-tts` package may warn about missing SoX. This is only needed for certain audio format conversions and does not affect core TTS functionality.

### Language and Voice Notes

- **Cross-lingual performance varies** — each built-in speaker has a native language. Using a speaker outside their native language (e.g. Vivian for English) works but may have higher word error rates.
- **Voice clone fidelity** — the `x_vector_only_mode` (speaker embedding only) is faster but produces lower-quality clones than full prompt-based cloning with `ref_text`.
- **10 languages supported** — Chinese, English, Japanese, Korean, German, French, Russian, Portuguese, Spanish, and Italian. Other languages are not supported and may produce unintelligible output.

## Resources

- [Qwen3-TTS GitHub](https://github.com/QwenLM/Qwen3-TTS)
- [Qwen3-TTS HuggingFace Collection](https://huggingface.co/collections/Qwen/qwen3-tts)
- [Vision Agents — Create Your Own Plugin](https://visionagents.ai/integrations/create-your-own-plugin)
- [Vision Agents — HuggingFace Transformers](https://visionagents.ai/integrations/llm/huggingface-transformers)
- [Stream Video & Audio](https://getstream.io/video/)
- [Sign up for Stream (free)](https://getstream.io/try-for-free/)
