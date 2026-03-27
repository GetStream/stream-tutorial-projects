"""
Voxtral TTS + Vision Agents — Quick Start

Demonstrates two ways to use the Voxtral TTS plugin:
1. Basic TTS with a saved voice ID
2. Zero-shot voice cloning with a reference audio clip

Both use the voxtral-mini-tts-2603 model.

Required env vars:
    MISTRAL_API_KEY, DEEPGRAM_API_KEY, GOOGLE_API_KEY,
    STREAM_API_KEY, STREAM_API_SECRET
"""

import asyncio
import logging

from dotenv import load_dotenv
from vision_agents.core import Agent, Runner, User
from vision_agents.core.agents import AgentLauncher
from vision_agents.plugins import deepgram, gemini, getstream, smart_turn

from plugins.voxtral.vision_agents.plugins.voxtral import TTS as VoxtralTTS

logger = logging.getLogger(__name__)

load_dotenv()


async def create_agent(**kwargs) -> Agent:
    """Create an agent with Voxtral TTS (voxtral-mini-tts-2603)."""
    agent = Agent(
        edge=getstream.Edge(),
        agent_user=User(name="Voxtral AI", id="agent"),
        instructions=(
            "You are a helpful, friendly voice assistant powered by "
            "Voxtral TTS. Keep responses brief and conversational."
        ),
        tts=VoxtralTTS(
            model="voxtral-mini-tts-2603",
            response_format="pcm",
        ),
        stt=deepgram.STT(eager_turn_detection=True),
        llm=gemini.LLM("gemini-3-flash-preview"),
        turn_detection=smart_turn.TurnDetection(
            silence_duration_ms=2000,
            speech_probability_threshold=0.5,
        ),
    )
    return agent


async def join_call(agent: Agent, call_type: str, call_id: str, **kwargs) -> None:
    """Join the call and start the agent."""
    call = await agent.create_call(call_type, call_id)

    logger.info("Starting Voxtral TTS Agent...")

    async with agent.join(call):
        logger.info("Agent joined call")

        await asyncio.sleep(3)
        await agent.llm.simple_response(
            text="Hello! I'm powered by Voxtral TTS from Mistral."
        )

        await agent.finish()


if __name__ == "__main__":
    Runner(AgentLauncher(create_agent=create_agent, join_call=join_call)).cli()
