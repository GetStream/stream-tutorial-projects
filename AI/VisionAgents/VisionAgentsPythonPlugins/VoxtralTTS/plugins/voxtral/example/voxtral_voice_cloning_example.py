"""
Voxtral TTS Voice Cloning Example

This example demonstrates zero-shot voice cloning with Voxtral TTS (Mistral)
and Vision Agents. Voxtral can clone any voice from as little as 2-3 seconds
of audio, capturing emotion, speaking style, and accent.

Two approaches are shown:
1. On-the-fly cloning with ref_audio (base64-encoded audio clip)
2. Using a saved voice_id created via the Mistral Voices API

This example creates an agent that uses:
- Voxtral TTS with voice cloning for text-to-speech (voxtral-mini-tts-2603)
- Deepgram for speech-to-text
- Gemini for LLM
- GetStream for edge/real-time communication

Requirements:
- MISTRAL_API_KEY environment variable
- DEEPGRAM_API_KEY environment variable
- GOOGLE_API_KEY environment variable
- STREAM_API_KEY and STREAM_API_SECRET environment variables
- A reference audio file (david.wav) for voice cloning
"""

import asyncio
import base64
import logging
import os
import sys
from pathlib import Path

from dotenv import load_dotenv
from mistralai.client import Mistral
from vision_agents.core import Agent, Runner, User
from vision_agents.core.agents import AgentLauncher
from vision_agents.plugins import deepgram, gemini, getstream

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from vision_agents.plugins.voxtral import TTS as VoxtralTTS

logger = logging.getLogger(__name__)

load_dotenv()

PROJECT_ROOT = Path(__file__).resolve().parents[3]
REF_AUDIO_PATH = PROJECT_ROOT / "david.wav"


def create_saved_voice(audio_path: Path = REF_AUDIO_PATH) -> str:
    """
    Create a saved voice via the Mistral Voices API.

    Once created, the voice can be reused across requests by its ID,
    avoiding the need to pass ref_audio every time.

    Args:
        audio_path: Path to audio file (3-25s, single speaker, clean WAV/MP3).

    Returns:
        The voice ID string.
    """
    client = Mistral(api_key=os.environ["MISTRAL_API_KEY"])

    sample_audio_b64 = base64.b64encode(audio_path.read_bytes()).decode()

    voice = client.audio.voices.create(
        name="david-cloned-voice",
        sample_audio=sample_audio_b64,
        sample_filename=audio_path.name,
        languages=["en"],
    )

    logger.info("Created voice: %s (id=%s)", voice.name, voice.id)
    return voice.id


async def create_agent_with_ref_audio(**kwargs) -> Agent:
    """
    Create an agent using on-the-fly voice cloning via ref_audio.

    Pass a base64-encoded audio clip directly to clone a voice without
    creating a saved voice first. Best for one-off use or experimentation.
    """
    ref_audio_b64 = base64.b64encode(REF_AUDIO_PATH.read_bytes()).decode()

    agent = Agent(
        edge=getstream.Edge(),
        agent_user=User(name="Cloned Voice AI", id="agent"),
        instructions=(
            "You are a voice assistant that sounds like the person in the "
            "reference audio. Keep responses natural and conversational."
        ),
        tts=VoxtralTTS(
            model="voxtral-mini-tts-2603",
            ref_audio=ref_audio_b64,
            response_format="pcm",
        ),
        stt=deepgram.STT(eager_turn_detection=True),
        llm=gemini.LLM("gemini-3-flash-preview"),
    )
    return agent


async def create_agent_with_voice_id(**kwargs) -> Agent:
    """
    Create an agent using a previously saved voice ID.

    Saved voices provide consistent results and avoid sending the
    reference audio with every request. Set VOXTRAL_VOICE_ID in .env
    or pass voice_id in kwargs.
    """
    voice_id = kwargs.get("voice_id") or os.environ.get("VOXTRAL_VOICE_ID")
    if not voice_id:
        logger.info("No voice_id provided, creating a saved voice from %s...", REF_AUDIO_PATH.name)
        voice_id = create_saved_voice(REF_AUDIO_PATH)

    agent = Agent(
        edge=getstream.Edge(),
        agent_user=User(name="Cloned Voice AI", id="agent"),
        instructions=(
            "You are a voice assistant with a custom cloned voice. "
            "Keep responses short, friendly, and natural."
        ),
        tts=VoxtralTTS(
            model="voxtral-mini-tts-2603",
            voice_id=voice_id,
            response_format="pcm",
        ),
        stt=deepgram.STT(eager_turn_detection=True),
        llm=gemini.LLM("gemini-3-flash-preview"),
    )
    return agent


async def join_call(agent: Agent, call_type: str, call_id: str, **kwargs) -> None:
    """Join the call and start the agent."""
    call = await agent.create_call(call_type, call_id)

    logger.info("Starting Voxtral Voice Cloning Agent...")

    async with agent.join(call):
        logger.info("Agent joined call with cloned voice")

        await asyncio.sleep(3)
        await agent.llm.simple_response(
            text="Hello! I'm speaking with a cloned voice powered by Voxtral TTS."
        )

        await agent.finish()


if __name__ == "__main__":
    Runner(
        AgentLauncher(
            create_agent=create_agent_with_ref_audio,
            join_call=join_call,
        )
    ).cli()
