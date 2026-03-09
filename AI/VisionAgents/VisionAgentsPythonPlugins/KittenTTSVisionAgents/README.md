# KittenTTS Plugin for Vision Agents

An ultra-lightweight Text-to-Speech (TTS) plugin for [Vision Agents](https://github.com/GetStream/Vision-Agents) powered by [KittenTTS](https://github.com/KittenML/KittenTTS). Runs efficiently on CPU with no GPU required and a model size under 25MB (int8).

## Features

- Runs on CPU — no GPU required
- Ultra-lightweight: model sizes from 25MB (int8) to 80MB (mini)
- Multiple high-quality voice options
- Adjustable speech speed
- Multiple model sizes to balance quality vs. resource usage

## Installation

```bash
pip install vision-agents-plugins-kittentts
```

Or with uv:

```bash
uv add vision-agents-plugins-kittentts
```

## Usage

```python
from vision_agents.plugins import kittentts

# Create TTS with default settings (mini model, Bella voice)
tts = kittentts.TTS()

# Or specify model and voice
tts = kittentts.TTS(
    model="KittenML/kitten-tts-mini-0.8",
    voice="Jasper",
    speed=1.0,
)

# Or use the nano int8 model for minimal footprint
tts = kittentts.TTS(
    model="KittenML/kitten-tts-nano-0.8-int8",
    voice="Luna",
)
```

### Full Agent Example

```python
import asyncio
from dotenv import load_dotenv
from vision_agents.core import Agent, Runner, User
from vision_agents.core.agents import AgentLauncher
from vision_agents.plugins import deepgram, gemini, getstream, kittentts

load_dotenv()

async def create_agent(**kwargs) -> Agent:
    agent = Agent(
        edge=getstream.Edge(),
        agent_user=User(name="Kitten AI", id="agent"),
        instructions="You are a helpful voice assistant.",
        tts=kittentts.TTS(voice="Bella"),
        stt=deepgram.STT(eager_turn_detection=True),
        llm=gemini.LLM("gemini-3-flash-preview"),
    )
    return agent

async def join_call(agent, call_type, call_id, **kwargs):
    await agent.create_user()
    call = await agent.create_call(call_type, call_id)
    async with agent.join(call):
        await asyncio.sleep(3)
        await agent.llm.simple_response(text="Hello from KittenTTS!")
        await agent.finish()

if __name__ == "__main__":
    Runner(AgentLauncher(create_agent=create_agent, join_call=join_call)).cli()
```

## Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `model` | `str` | `"KittenML/kitten-tts-mini-0.8"` | HuggingFace model ID |
| `voice` | `str` | `"Bella"` | Voice name for synthesis |
| `speed` | `float` | `1.0` | Speech speed multiplier |
| `client` | `KittenTTS \| None` | `None` | Pre-initialized KittenTTS instance |

## Available Models

| Model | Params | Size | HuggingFace |
|-------|--------|------|-------------|
| kitten-tts-mini | 80M | 80MB | `KittenML/kitten-tts-mini-0.8` |
| kitten-tts-micro | 40M | 41MB | `KittenML/kitten-tts-micro-0.8` |
| kitten-tts-nano | 15M | 56MB | `KittenML/kitten-tts-nano-0.8` |
| kitten-tts-nano-int8 | 15M | 25MB | `KittenML/kitten-tts-nano-0.8-int8` |

## Available Voices

`Bella`, `Jasper`, `Luna`, `Bruno`, `Rosie`, `Hugo`, `Kiki`, `Leo`

## Requirements

- Python 3.10+
- vision-agents
- kittentts 0.8+

## Testing

```bash
cd plugins/kittentts
uv sync
uv run pytest -v -m integration
```

## Dependencies

- [vision-agents](https://github.com/GetStream/Vision-Agents) — Agent framework
- [KittenTTS](https://github.com/KittenML/KittenTTS) — Ultra-lightweight TTS model
- numpy — Audio array processing
- soundfile — WAV file output (for examples/tests)
