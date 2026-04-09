# Neu TTS Plugin

An on-device Text-to-Speech (TTS) plugin for [Vision Agents](https://github.com/GetStream/Vision-Agents) powered by [Neuphonic's](https://www.neuphonic.com/) [Neu TTS](https://github.com/neuphonic/neutts) models. Runs locally on CPU with instant voice cloning, multilingual support, and no API key required.

## Features

- Runs on CPU — no GPU or API key required
- Real-time on-device inference
- Instant voice cloning with as little as 3 seconds of reference audio
- Multilingual support (English, French, German, Spanish)
- Multiple model sizes (Air ~360M params, Nano ~120M params)
- GGUF quantized variants for lower memory and faster inference

## Installation

```bash
uv add "vision-agents[neutts]"
# or directly
uv add vision-agents-plugins-neutts
```

### Platform-specific setup

Neu TTS uses `espeak-ng` for phonemization. Install it for your platform:

```bash
# macOS
brew install espeak-ng

# Ubuntu/Debian
sudo apt-get install espeak-ng

# Windows — download from https://github.com/espeak-ng/espeak-ng/releases
```

For GGUF model support (recommended for streaming), install `llama-cpp-python` with hardware acceleration. See the [Neu TTS README](https://github.com/neuphonic/neutts#get-started-with-neutts) for platform-specific build flags.

## Usage

```python
from vision_agents.plugins import neutts

# Basic usage with default Nano model
tts = neutts.TTS()

# Use the larger Air model for higher quality
tts = neutts.TTS(backbone="neuphonic/neutts-air")

# Use a GGUF quantized model for faster CPU inference
tts = neutts.TTS(
    backbone="neuphonic/neutts-nano-q8-gguf",
    codec_repo="neuphonic/neucodec-onnx-decoder",
)

# Voice cloning with custom reference audio
tts = neutts.TTS(
    ref_audio_path="path/to/voice.wav",
    ref_text="Transcript of the reference audio.",
)

# Multilingual (French)
tts = neutts.TTS(backbone="neuphonic/neutts-nano-french")
```

## Configuration

| Parameter | Description | Default |
|---|---|---|
| `backbone` | HuggingFace backbone model repo | `"neuphonic/neutts-nano"` |
| `backbone_device` | Device for the backbone (`"cpu"` or `"gpu"`) | `"cpu"` |
| `codec_repo` | HuggingFace codec repo | `"neuphonic/neucodec"` |
| `codec_device` | Device for the codec (`"cpu"`) | `"cpu"` |
| `language` | Language code (auto-detected from backbone) | `None` |
| `ref_audio_path` | Path to reference `.wav` file for voice cloning | `None` |
| `ref_text` | Transcript of the reference audio (string or path to `.txt`) | `None` |
| `client` | Optional pre-initialized `NeuTTS` instance | `None` |

## Available Backbones

### English
- `neuphonic/neutts-air` — 360M params, highest quality
- `neuphonic/neutts-air-q4-gguf` / `neuphonic/neutts-air-q8-gguf` — quantized Air
- `neuphonic/neutts-nano` — 120M params, fast
- `neuphonic/neutts-nano-q4-gguf` / `neuphonic/neutts-nano-q8-gguf` — quantized Nano

### French
- `neuphonic/neutts-nano-french` / `neuphonic/neutts-nano-french-q4-gguf` / `neuphonic/neutts-nano-french-q8-gguf`

### German
- `neuphonic/neutts-nano-german` / `neuphonic/neutts-nano-german-q4-gguf` / `neuphonic/neutts-nano-german-q8-gguf`

### Spanish
- `neuphonic/neutts-nano-spanish` / `neuphonic/neutts-nano-spanish-q4-gguf` / `neuphonic/neutts-nano-spanish-q8-gguf`

## Voice Cloning

Neu TTS supports instant voice cloning from a short reference audio sample:

1. Prepare a `.wav` file (3–15 seconds, mono, 16–44kHz, clean speech)
2. Provide a transcript of the reference audio
3. Pass both to the TTS constructor

```python
tts = neutts.TTS(
    ref_audio_path="my_voice.wav",
    ref_text="This is the transcript of what is said in my_voice.wav.",
)
```

For faster startup, pre-encode the reference audio and save the tensor:

```python
from neutts import NeuTTS
import torch

model = NeuTTS(backbone_repo="neuphonic/neutts-nano")
ref_codes = model.encode_reference("my_voice.wav")
torch.save(ref_codes, "my_voice.pt")
```

The plugin automatically loads `.pt` files when found alongside the `.wav` reference.

## Dependencies

- neutts>=1.2.0
- espeak-ng (system dependency)
- PyTorch 2.8+
