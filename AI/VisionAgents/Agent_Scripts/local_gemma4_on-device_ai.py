"""
Local on-device voice AI agent powered by Gemma 4 E2B via HuggingFace Transformers.

Runs the model entirely on Apple Silicon (MPS) or GPU — no cloud API calls for inference.
Requires:
  - HF_TOKEN in .env (Gemma 4 is a gated model)
  - STREAM_API_KEY / STREAM_API_SECRET for real-time transport
  - DEEPGRAM_API_KEY for speech-to-text and text-to-speech

Usage:
    uv run python local_gemma4_on-device_ai.py
"""

import logging
import os
from pathlib import Path

from dotenv import load_dotenv

_ROOT = Path(__file__).resolve().parent
load_dotenv(_ROOT / ".env")

from vision_agents.core import Agent, AgentLauncher, Runner, User
from vision_agents.core.utils.examples import get_weather_by_location
from vision_agents.plugins import deepgram, getstream, huggingface

logger = logging.getLogger(__name__)

GEMMA4_MODEL = os.getenv("GEMMA4_MODEL", "google/gemma-4-E2B-it")

INSTRUCTIONS = (
    "You are a friendly voice assistant running locally on-device with Gemma 4. "
    "Keep your responses concise and conversational since you are in a live voice call. "
    "Avoid special characters, markdown, or formatting — speak naturally. "
    "You can help with general questions, weather lookups, and everyday tasks."
)


def setup_llm() -> huggingface.TransformersLLM:
    llm = huggingface.TransformersLLM(
        model=GEMMA4_MODEL,
        device="mps",
        torch_dtype="float16",
        max_new_tokens=256,
        max_tool_rounds=3,
    )

    @llm.register_function(description="Get current weather for a location")
    async def get_weather(location: str) -> dict[str, object]:
        return await get_weather_by_location(location)

    return llm


async def create_agent(**kwargs) -> Agent:
    if not os.getenv("STREAM_API_KEY") or not os.getenv("STREAM_API_SECRET"):
        raise RuntimeError(
            f"Set STREAM_API_KEY and STREAM_API_SECRET in {_ROOT / '.env'} "
            "(Stream dashboard → your app → API keys)."
        )
    if not os.getenv("HF_TOKEN"):
        raise RuntimeError(
            "HF_TOKEN is required for gated Gemma 4 models. "
            "Get one at https://huggingface.co/settings/tokens and add it to .env."
        )

    llm = setup_llm()

    agent = Agent(
        edge=getstream.Edge(),
        agent_user=User(name="Gemma 4 Assistant", id="agent"),
        instructions=INSTRUCTIONS,
        llm=llm,
        stt=deepgram.STT(),
        tts=deepgram.TTS(),
    )

    return agent


async def join_call(agent: Agent, call_type: str, call_id: str, **kwargs) -> None:
    call = await agent.create_call(call_type, call_id)

    async with agent.join(call):
        await agent.simple_response("Hello! I'm your local Gemma 4 assistant. How can I help?")
        await agent.finish()


if __name__ == "__main__":
    Runner(AgentLauncher(create_agent=create_agent, join_call=join_call)).cli()
