# TADA TTS Plugin

A Text-to-Speech (TTS) plugin for [Vision Agents](https://github.com/GetStream/Vision-Agents) powered by Hume AI's [TADA](https://github.com/HumeAI/tada) (Text-Acoustic Dual Alignment) speech language model. TADA achieves fast, high-fidelity speech synthesis with zero hallucinations and supports voice cloning.

## Features

- Fast inference (~0.09 real-time factor, 5x faster than comparable LLM-based TTS)
- Zero hallucinations by construction (1:1 text-acoustic alignment)
- Voice cloning via reference audio
- Multilingual support (English + 9 languages with tada-3b-ml)
- Two model sizes: 1B (English) and 3B (multilingual)
- Dynamic duration and prosody per token

## Installation

```bash
uv add vision-agents-plugins-tada
# or directly
pip install vision-agents-plugins-tada
```

## Requirements

- CUDA-capable GPU (recommended for real-time performance)
- Python 3.10+
- PyTorch 2.7+

## Usage

```python
from vision_agents.plugins import tada

# Default: tada-3b-ml with built-in LJSpeech voice
tts = tada.TTS()

# English-only 1B model (faster, smaller)
tts = tada.TTS(model="HumeAI/tada-1b")

# Voice cloning with custom reference audio
tts = tada.TTS(
    voice="path/to/reference.wav",
    voice_transcript="Transcript of the reference audio.",
)

# Multilingual synthesis (German example)
tts = tada.TTS(
    model="HumeAI/tada-3b-ml",
    language="de",
    voice="path/to/german_reference.wav",
    voice_transcript="Transkript des Referenzaudios.",
)
```

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `model` | HuggingFace model ID | `"HumeAI/tada-3b-ml"` |
| `voice` | Path to reference WAV for voice cloning | Built-in LJSpeech sample |
| `voice_transcript` | Transcript of reference audio (required for non-English) | `None` |
| `language` | Encoder aligner language code | `None` (English) |
| `device` | PyTorch device string | `"cuda"` if available |
| `inference_options` | Advanced generation options | Default `InferenceOptions()` |

## Available Models

| Model | Parameters | Languages | HuggingFace |
|-------|-----------|-----------|-------------|
| `HumeAI/tada-1b` | 1B | English | [Link](https://huggingface.co/HumeAI/tada-1b) |
| `HumeAI/tada-3b-ml` | 3B | en, ar, ch, de, es, fr, it, ja, pl, pt | [Link](https://huggingface.co/HumeAI/tada-3b-ml) |

## Supported Languages

When using `HumeAI/tada-3b-ml`, pass the `language` parameter to select the appropriate aligner:

- `en` - English (default)
- `ar` - Arabic
- `ch` - Chinese
- `de` - German
- `es` - Spanish
- `fr` - French
- `it` - Italian
- `ja` - Japanese
- `pl` - Polish
- `pt` - Portuguese

For non-English reference audio, provide the `voice_transcript` parameter for accurate alignment.

## Advanced Configuration

Fine-tune generation with `InferenceOptions`:

```python
from tada.modules.tada import InferenceOptions
from vision_agents.plugins import tada

options = InferenceOptions(
    text_temperature=0.6,
    acoustic_cfg_scale=1.6,
    num_flow_matching_steps=20,
)

tts = tada.TTS(inference_options=options)
```

## Dependencies

- hume-tada>=0.1.6
- PyTorch 2.7+
- torchaudio
- transformers
