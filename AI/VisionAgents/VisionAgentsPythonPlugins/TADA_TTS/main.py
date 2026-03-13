"""
TADA TTS + Vision Agents Example

Demonstrates using TADA (Hume AI) as the TTS provider in a Vision Agents
voice AI pipeline with Deepgram STT, Gemini LLM, and GetStream transport.

Requirements:
    - CUDA-capable GPU
    - DEEPGRAM_API_KEY environment variable
    - GOOGLE_API_KEY environment variable
    - STREAM_API_KEY and STREAM_API_SECRET environment variables
"""

import asyncio
import logging

from dotenv import load_dotenv
from vision_agents.core import Agent, Runner, User
from vision_agents.core.agents import AgentLauncher
from vision_agents.plugins import deepgram, gemini, getstream, tada

logger = logging.getLogger(__name__)

load_dotenv()


async def create_agent(**kwargs) -> Agent:
    """Create a voice agent using TADA for text-to-speech."""
    tts = tada.TTS(model="HumeAI/tada-3b-ml")

    logger.info("Pre-loading TADA models (this may take a while on first run)...")
    await tts.warmup()

    agent = Agent(
        edge=getstream.Edge(),
        agent_user=User(name="TADA Voice Agent", id="agent"),
        instructions=(
            "You are a helpful voice assistant powered by TADA speech synthesis. "
            "Keep responses brief, natural, and conversational."
        ),
        tts=tts,
        stt=deepgram.STT(eager_turn_detection=True),
        llm=gemini.LLM("gemini-3-flash-preview"),
    )
    return agent


async def join_call(agent: Agent, call_type: str, call_id: str, **kwargs) -> None:
    """Join a call and run the voice agent."""
    call = await agent.create_call(call_type, call_id)

    logger.info("Starting TADA Voice Agent...")

    async with agent.join(call):
        logger.info("Agent joined call successfully")

        await asyncio.sleep(3)
        await agent.llm.simple_response(
            text="Hello! I'm your voice assistant powered by TADA speech synthesis."
        )

        await agent.finish()


if __name__ == "__main__":
    Runner(AgentLauncher(create_agent=create_agent, join_call=join_call)).cli()
