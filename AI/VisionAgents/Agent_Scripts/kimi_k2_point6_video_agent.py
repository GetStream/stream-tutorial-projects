"""
Realtime video-understanding agent powered by Kimi K2.6 (Moonshot AI).

Kimi K2.6 is a native multimodal model that accepts text, image, and video input.
This agent uses the OpenAI-compatible Chat Completions API via ChatCompletionsVLM
to buffer live video frames and send them alongside user speech transcripts.

Requires in .env:
  - STREAM_API_KEY / STREAM_API_SECRET  (getstream.io dashboard)
  - MOONSHOT_API_KEY                    (platform.kimi.ai)
  - DEEPGRAM_API_KEY                    (deepgram.com)
  - ELEVENLABS_API_KEY                  (elevenlabs.io)

Usage:
    uv run python plugins/kimi_k2_point6_video_agent.py run
"""

import logging
import os
from pathlib import Path

from dotenv import load_dotenv

_ROOT = Path(__file__).resolve().parent.parent
load_dotenv(_ROOT / ".env")

from vision_agents.core import Agent, AgentLauncher, Runner, User
from vision_agents.core.utils.examples import get_weather_by_location
from vision_agents.plugins import deepgram, elevenlabs, getstream, openai

logger = logging.getLogger(__name__)

KIMI_MODEL = "kimi-k2.6"
KIMI_BASE_URL = "https://api.moonshot.ai/v1"

INSTRUCTIONS = (
    "You are a real-time video assistant powered by Kimi K2.6. "
    "You can see the user's camera feed and hear them speak. "
    "Describe what you observe when asked, answer visual questions, and provide "
    "helpful commentary about the scene. Keep responses concise and conversational "
    "since this is a live video call. Avoid markdown, special characters, or formatting."
)


def setup_llm() -> openai.ChatCompletionsVLM:
    api_key = os.getenv("MOONSHOT_API_KEY")
    if not api_key:
        raise RuntimeError(
            "MOONSHOT_API_KEY is required. Get one at https://platform.kimi.ai "
            "and add it to .env."
        )

    llm = openai.ChatCompletionsVLM(
        model=KIMI_MODEL,
        base_url=KIMI_BASE_URL,
        api_key=api_key,
        fps=1,
        frame_buffer_seconds=10,
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

    llm = setup_llm()

    agent = Agent(
        edge=getstream.Edge(),
        agent_user=User(name="Kimi K2.6 Video Assistant", id="agent"),
        instructions=INSTRUCTIONS,
        llm=llm,
        stt=deepgram.STT(),
        tts=elevenlabs.TTS(),
    )

    return agent


async def join_call(agent: Agent, call_type: str, call_id: str, **kwargs) -> None:
    call = await agent.create_call(call_type, call_id)

    async with agent.join(call):
        await agent.simple_response(
            "Hello! I'm your Kimi K2.6 video assistant. "
            "I can see your camera feed — ask me anything about what's on screen."
        )
        await agent.finish()


if __name__ == "__main__":
    Runner(AgentLauncher(create_agent=create_agent, join_call=join_call)).cli()
