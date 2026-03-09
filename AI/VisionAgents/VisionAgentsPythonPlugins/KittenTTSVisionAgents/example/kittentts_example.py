"""
KittenTTS Example

This example demonstrates KittenTTS integration with Vision Agents.

This example creates an agent that uses:
- KittenTTS for text-to-speech (runs locally on CPU, under 25MB)
- Deepgram for speech-to-text
- Gemini for LLM
- GetStream for edge/real-time communication

Requirements:
- DEEPGRAM_API_KEY environment variable
- GOOGLE_API_KEY environment variable
- STREAM_API_KEY and STREAM_API_SECRET environment variables
"""

import asyncio
import logging

from dotenv import load_dotenv
from vision_agents.core import Agent, Runner, User
from vision_agents.core.agents import AgentLauncher
from vision_agents.plugins import deepgram, gemini, getstream
from vision_agents.plugins import kittentts

logger = logging.getLogger(__name__)

load_dotenv()


async def create_agent(**kwargs) -> Agent:
    """Create the agent with KittenTTS."""
    agent = Agent(
        edge=getstream.Edge(),
        agent_user=User(name="Kitten AI", id="agent"),
        instructions="You are a helpful voice assistant. Keep responses brief and conversational.",
        tts=kittentts.TTS(
            model="KittenML/kitten-tts-mini-0.8",
            # available_voices : ['Bella', 'Jasper', 'Luna', 'Bruno', 'Rosie', 'Hugo', 'Kiki', 'Leo']
            voice="Bella",
        ),
        stt=deepgram.STT(eager_turn_detection=True),
        llm=gemini.LLM("gemini-3-flash-preview"),
    )
    return agent


async def join_call(agent: Agent, call_type: str, call_id: str, **kwargs) -> None:
    """Join the call and start the agent."""
    await agent.create_user()
    call = await agent.create_call(call_type, call_id)

    logger.info("Starting KittenTTS Agent...")

    async with agent.join(call):
        logger.info("Agent joined call")

        await asyncio.sleep(3)
        await agent.llm.simple_response(
            text="Hello! I'm running KittenTTS, an ultra-lightweight text-to-speech model."
        )

        await agent.finish()


if __name__ == "__main__":
    Runner(AgentLauncher(create_agent=create_agent, join_call=join_call)).cli()
