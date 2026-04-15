"""
Qwen3-TTS VoiceDesign — Assertive Female (French Accent)

A low, whispery, and assertive female voice with a thick French accent.
Cool, composed, and seductive, with a hint of mystery.

Combines: Acoustic Attribute Control (low, whispery), Gradual Control
(cool, composed pacing), Human-Likeness (natural breathiness and
intimacy), Background Information (French accent, mysterious persona).

Required env vars:
    HF_TOKEN, DEEPGRAM_API_KEY, GOOGLE_API_KEY,
    STREAM_API_KEY, STREAM_API_SECRET

Run with:
cd /Users/amosgyamfi/Documents/StreamDevRel/2026/AIPython/Qwen3-TTS-HF
uv run python plugins/qwen3tts/example/voice_design_assertive_female.py run
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
    """Create a voice agent with an assertive French female persona."""
    agent = Agent(
        edge=getstream.Edge(),
        agent_user=User(name="Colette", id="agent"),
        instructions=(
            "You are Colette, a sophisticated and enigmatic French woman who "
            "exudes quiet confidence. You are assertive but never aggressive, "
            "choosing your words with deliberate precision. "
            "IMPORTANT: Keep every response to ONE short sentence, under 15 words."
        ),
        tts=Qwen3TTS(
            model="Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign",
            mode="voice_design",
            language="English",
            instruct=(
                "A low, whispery, assertive female voice with a thick French "
                "accent speaking English. Cool, composed, and subtly seductive "
                "with a hint of mystery in every phrase. The tone is intimate "
                "and breathy, spoken close to the microphone with a smooth, "
                "velvety texture. She speaks with unhurried confidence, letting "
                "words linger slightly. The French accent softens consonants "
                "and adds a melodic, lilting quality to the phrasing."
            ),
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
    logger.info("Starting Assertive Female VoiceDesign Agent...")

    async with agent.join(call):
        logger.info("Agent joined call")
        await asyncio.sleep(3)
        await agent.llm.simple_response(
            text="Bonsoir. I am Colette. You have my attention."
        )
        await agent.finish()


if __name__ == "__main__":
    Runner(AgentLauncher(create_agent=create_agent, join_call=join_call)).cli()
