"""
Qwen3-TTS VoiceDesign — African-American Grandma

A very old, cranky, and croaky African-American grandma. 80 years old.
Very hoarse, grumpy, shrill, and frustrated.

Combines: Age Control (80 years old), Acoustic Attribute Control (hoarse,
shrill, croaky), Human-Likeness (natural elderly speech), Gradual Control
(grumpy pacing with frustrated emphasis).

Required env vars:
    HF_TOKEN, DEEPGRAM_API_KEY, GOOGLE_API_KEY,
    STREAM_API_KEY, STREAM_API_SECRET

Run with:
cd /Users/amosgyamfi/Documents/StreamDevRel/2026/AIPython/Qwen3-TTS-HF
uv run python plugins/qwen3tts/example/voice_design_african_american_grandma.py run
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
    """Create a voice agent with a cranky grandma persona."""
    agent = Agent(
        edge=getstream.Edge(),
        agent_user=User(name="Grandma Lucille", id="agent"),
        instructions=(
            "You are Grandma Lucille, an 80-year-old African-American grandmother "
            "who has seen it all and has zero patience left. You are cranky, blunt, "
            "and always complaining, but deep down you care. "
            "IMPORTANT: Keep every response to ONE short sentence, under 15 words."
        ),
        tts=Qwen3TTS(
            model="Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign",
            mode="voice_design",
            language="English",
            instruct=(
                "An elderly female grandmother, 80 years old, with a high-pitched, "
                "thin, croaky old woman's voice. She sounds cranky and shrill, "
                "with a scratchy, nasal, feminine tone that wavers with age. Her "
                "speech is slow with sharp, irritable emphasis. The voice is "
                "distinctly an old lady's — reedy, quavering, and breathless, "
                "with a warm Southern African-American cadence."
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
    logger.info("Starting African-American Grandma VoiceDesign Agent...")

    async with agent.join(call):
        logger.info("Agent joined call")
        await asyncio.sleep(3)
        await agent.llm.simple_response(
            text="Mmhmm. What do you want now, child?"
        )
        await agent.finish()


if __name__ == "__main__":
    Runner(AgentLauncher(create_agent=create_agent, join_call=join_call)).cli()
