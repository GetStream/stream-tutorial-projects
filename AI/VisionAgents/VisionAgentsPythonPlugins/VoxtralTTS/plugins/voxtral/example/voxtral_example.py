"""
Voxtral TTS Example

This example demonstrates Voxtral TTS (Mistral) integration with Vision Agents.

This example creates an agent that uses:
- Voxtral TTS for text-to-speech (voxtral-mini-tts-2603)
- Deepgram for speech-to-text
- Gemini for LLM
- GetStream for edge/real-time communication
- Smart Turn for turn detection

Requirements:
- MISTRAL_API_KEY environment variable
- DEEPGRAM_API_KEY environment variable
- GOOGLE_API_KEY environment variable
- STREAM_API_KEY and STREAM_API_SECRET environment variables
"""

import asyncio
import base64
import logging
from pathlib import Path

from dotenv import load_dotenv
from vision_agents.core import Agent, Runner, User
from vision_agents.core.agents import AgentLauncher
from vision_agents.plugins import deepgram, gemini, getstream, smart_turn

import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from vision_agents.plugins.voxtral import TTS as VoxtralTTS

logger = logging.getLogger(__name__)

load_dotenv()


async def create_agent(**kwargs) -> Agent:
    """Create the agent with Voxtral TTS."""
    ref_audio_path = Path(__file__).resolve().parents[3] / "david.wav"
    ref_audio_b64 = base64.b64encode(ref_audio_path.read_bytes()).decode()

    agent = Agent(
        edge=getstream.Edge(),
        agent_user=User(name="Voxtral AI", id="agent"),
        instructions=(
            "You are a friendly multilingual voice assistant powered by "
            "Voxtral TTS. Keep your responses short and conversational. "
            "You can speak in English, French, Spanish, Portuguese, Italian, "
            "Dutch, German, Hindi, and Arabic."
        ),
        tts=VoxtralTTS(
            model="voxtral-mini-tts-2603",
            ref_audio=ref_audio_b64,
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
