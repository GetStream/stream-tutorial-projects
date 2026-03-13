"""
TADA TTS Example

This example demonstrates TADA TTS integration with Vision Agents.

TADA (Text-Acoustic Dual Alignment) by Hume AI is a fast, reliable
speech generation model that runs locally on GPU. It achieves near-zero
hallucinations and supports voice cloning via reference audio.

This example creates an agent that uses:
- TADA for text-to-speech (runs locally on GPU)
- Deepgram for speech-to-text
- Gemini for LLM
- GetStream for edge/real-time communication

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
    """Create the agent with TADA TTS."""
    tts = tada.TTS(model="HumeAI/tada-3b-ml")

    logger.info("Pre-loading TADA models (this may take a while on first run)...")
    await tts.warmup()

    agent = Agent(
        edge=getstream.Edge(),
        agent_user=User(name="TADA AI", id="agent"),
        instructions="You are a helpful voice assistant. Keep responses brief and conversational.",
        tts=tts,
        stt=deepgram.STT(eager_turn_detection=True),
        llm=gemini.LLM("gemini-3-flash-preview"),
    )
    return agent


async def join_call(agent: Agent, call_type: str, call_id: str, **kwargs) -> None:
    """Join the call and start the agent."""
    call = await agent.create_call(call_type, call_id)

    logger.info("Starting TADA TTS Agent...")

    async with agent.join(call):
        logger.info("Agent joined call")

        await asyncio.sleep(3)
        await agent.llm.simple_response(text="Hello! I'm running TADA speech synthesis locally.")

        await agent.finish()


if __name__ == "__main__":
    Runner(AgentLauncher(create_agent=create_agent, join_call=join_call)).cli()
