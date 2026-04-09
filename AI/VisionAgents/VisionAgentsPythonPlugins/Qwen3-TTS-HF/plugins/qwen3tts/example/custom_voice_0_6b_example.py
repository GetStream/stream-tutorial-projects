"""
Qwen3-TTS CustomVoice (0.6B) + Vision Agents

Uses the smaller Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice model for
lower-resource environments. Supports the same 9 built-in speakers
but without instruction-based style control.

Speakers: Vivian, Serena, Uncle_Fu, Dylan, Eric, Ryan, Aiden, Ono_Anna, Sohee

Required env vars:
    HF_TOKEN, DEEPGRAM_API_KEY, GOOGLE_API_KEY,
    STREAM_API_KEY, STREAM_API_SECRET
"""

import asyncio
import logging
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(PROJECT_ROOT))

from dotenv import load_dotenv
from vision_agents.core import Agent, Runner, User
from vision_agents.core.agents import AgentLauncher
from vision_agents.plugins import deepgram, gemini, getstream, smart_turn

from plugins.qwen3tts.vision_agents.plugins.qwen3tts import TTS as Qwen3TTS

logger = logging.getLogger(__name__)

load_dotenv()


async def create_agent(**kwargs) -> Agent:
    """Create a voice agent with Qwen3-TTS 0.6B CustomVoice (lightweight)."""
    agent = Agent(
        edge=getstream.Edge(),
        agent_user=User(name="Qwen3 TTS AI", id="agent"),
        instructions=(
            "You are a helpful, friendly voice assistant. "
            "Keep responses brief and conversational."
        ),
        tts=Qwen3TTS(
            model="Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice",
            mode="custom_voice",
            speaker="Ryan",
            language="English",
        ),
        stt=deepgram.STT(eager_turn_detection=True),
        llm=gemini.LLM("gemini-2.5-flash"),
        turn_detection=smart_turn.TurnDetection(
            silence_duration_ms=2000,
            speech_probability_threshold=0.5,
        ),
    )
    return agent


async def join_call(agent: Agent, call_type: str, call_id: str, **kwargs) -> None:
    call = await agent.create_call(call_type, call_id)
    logger.info("Starting Qwen3-TTS CustomVoice 0.6B Agent...")

    async with agent.join(call):
        logger.info("Agent joined call")
        await asyncio.sleep(3)
        await agent.llm.simple_response(
            text="Hey there! I'm the lightweight Qwen3-TTS running on the 0.6B model."
        )
        await agent.finish()


if __name__ == "__main__":
    Runner(AgentLauncher(create_agent=create_agent, join_call=join_call)).cli()
