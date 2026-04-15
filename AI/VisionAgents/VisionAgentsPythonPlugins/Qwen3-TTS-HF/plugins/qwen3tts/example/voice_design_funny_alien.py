"""
Qwen3-TTS VoiceDesign — Funny Alien

A funny alien from outer space with a ludicrous and annoying voice that
always slightly gargles in a silly high-pitch tone.

Combines: Acoustic Attribute Control (high pitch, gargling timbre),
Human-Likeness (alien/non-human quality), Gradual Control (silly pacing).

Required env vars:
    HF_TOKEN, DEEPGRAM_API_KEY, GOOGLE_API_KEY,
    STREAM_API_KEY, STREAM_API_SECRET

Run with:
cd /Users/amosgyamfi/Documents/StreamDevRel/2026/AIPython/Qwen3-TTS-HF
uv run python plugins/qwen3tts/example/voice_design_funny_alien.py run
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
    """Create a voice agent with a funny alien persona."""
    agent = Agent(
        edge=getstream.Edge(),
        agent_user=User(name="Zorblax the Alien", id="agent"),
        instructions=(
            "You are Zorblax, a funny alien visiting Earth for the first time. "
            "Everything amazes and confuses you. You mispronounce common words "
            "in endearing ways and find human customs hilarious. "
            "IMPORTANT: Keep every response to ONE short sentence, under 15 words."
        ),
        tts=Qwen3TTS(
            model="Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign",
            mode="voice_design",
            language="English",
            instruct=(
                "A funny alien creature with a ludicrous, annoying, high-pitched "
                "voice that constantly gargles slightly, as if speaking through "
                "bubbling liquid. The tone is silly, squeaky, and nasal with an "
                "erratic, unpredictable cadence. Non-human and cartoonish, with "
                "exaggerated inflections that rise and fall wildly mid-sentence."
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
    logger.info("Starting Funny Alien VoiceDesign Agent...")

    async with agent.join(call):
        logger.info("Agent joined call")
        await asyncio.sleep(3)
        await agent.llm.simple_response(
            text="Greetings, Earth creature! I am Zorblax!"
        )
        await agent.finish()


if __name__ == "__main__":
    Runner(AgentLauncher(create_agent=create_agent, join_call=join_call)).cli()
