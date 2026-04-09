# Neu TTS Examples

This directory contains examples demonstrating how to use the Neu TTS plugin with Vision Agents for different real-world use cases.

## Examples

| Example | Description |
|---|---|
| `basic_example.py` | Simple voice assistant with Neu TTS |
| `tech_support_example.py` | Technical support agent that troubleshoots issues |
| `customer_service_example.py` | Customer service representative for inquiries and complaints |
| `outbound_recruitment_example.py` | Recruitment agent for candidate outreach and screening |
| `outbound_sales_example.py` | Sales development representative for outbound prospecting |
| `healthcare_example.py` | Healthcare assistant for appointment scheduling and triage |
| `inventory_management_example.py` | Warehouse inventory management and tracking assistant |

## Setup

1. Install dependencies:

```bash
cd plugins/neutts/example
uv sync
```

2. Install system dependencies:

```bash
# macOS
brew install espeak-ng

# Ubuntu/Debian
sudo apt-get install espeak-ng
```

3. Create a `.env` file with your API keys:

```bash
# Required for speech-to-text (Deepgram)
DEEPGRAM_API_KEY=your_deepgram_api_key

# Required for LLM (Gemini)
GOOGLE_API_KEY=your_google_api_key

# Required for real-time communication (Stream)
STREAM_API_KEY=your_stream_api_key
STREAM_API_SECRET=your_stream_api_secret
```

> Neu TTS itself does **not** require an API key — it runs entirely on-device.

## Running the Examples

```bash
# Basic example
uv run basic_example.py run

# Tech Support
uv run tech_support_example.py run

# Customer Service
uv run customer_service_example.py run

# Outbound Recruitment
uv run outbound_recruitment_example.py run

# Outbound Sales
uv run outbound_sales_example.py run

# Healthcare
uv run healthcare_example.py run

# Inventory Management
uv run inventory_management_example.py run
```

## Customization

### Change the voice model

```python
# Use the larger Air model for higher quality
tts = neutts.TTS(backbone="neuphonic/neutts-air")

# Use a quantized model for faster inference
tts = neutts.TTS(
    backbone="neuphonic/neutts-nano-q8-gguf",
    codec_repo="neuphonic/neucodec-onnx-decoder",
)
```

### Voice cloning

```python
tts = neutts.TTS(
    ref_audio_path="path/to/your/voice.wav",
    ref_text="Transcript of what is spoken in the wav file.",
)
```

### Multilingual

```python
# French
tts = neutts.TTS(backbone="neuphonic/neutts-nano-french")

# German
tts = neutts.TTS(backbone="neuphonic/neutts-nano-german")

# Spanish
tts = neutts.TTS(backbone="neuphonic/neutts-nano-spanish")
```

## Limitations

- **English only (Air model):** NeuTTS Air supports English only. The Nano multilingual collection adds French, German, and Spanish, but each language requires its own model variant.
- **Context window:** The 2048-token context window limits generation to ~30 seconds of audio (including the reference prompt). Longer texts must be split into segments.
- **Reference audio required:** Voice cloning always needs a 3–15 second reference `.wav` and its transcript. There is no built-in "default voice" — when none is provided, this plugin downloads a sample from GitHub automatically.
- **Reference audio quality sensitive:** Best results require clean, mono, 16–44 kHz WAV files with minimal background noise and natural continuous speech. Poor-quality references degrade output significantly.
- **First-run model download:** The backbone and codec must be downloaded from HuggingFace on first use (~900 MB for Nano, ~2.3 GB for the codec). Subsequent runs use the cached models.
- **CPU inference latency:** While real-time on modern hardware, inference on older or low-power CPUs may be slower than cloud-based TTS APIs. Use GGUF quantized backbones with the ONNX codec decoder for best on-device performance.
- **No streaming with torch backend:** Streaming synthesis (`infer_stream`) is only supported with GGUF backbones via `llama-cpp-python`. The default torch backend generates complete audio in a single pass.
- **Watermarking dependency:** The Perth watermarker may not install cleanly in all environments (especially with `uv sync`). Audio will still generate but without the embedded watermark.

## Additional Resources

- [Neu TTS on GitHub](https://github.com/neuphonic/neutts)
- [Neuphonic](https://www.neuphonic.com/)
- [Vision Agents Documentation](https://visionagents.ai)
