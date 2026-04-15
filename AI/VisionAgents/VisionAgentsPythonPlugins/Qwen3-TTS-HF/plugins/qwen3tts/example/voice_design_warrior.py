"""
Qwen3-TTS VoiceDesign — Warrior (Japanese Accent)

A calm, husky voice with a thick Japanese accent. Soft, whiskery,
low tone, with a composed, gentle pacing.

Combines: Acoustic Attribute Control (husky, whiskery, low tone),
Gradual Control (composed, gentle pacing), Human-Likeness (natural
breath and softness), Background Information (Japanese warrior persona).

Required env vars:
    HF_TOKEN, DEEPGRAM_API_KEY, GOOGLE_API_KEY,
    STREAM_API_KEY, STREAM_API_SECRET

Run with:
cd /Users/amosgyamfi/Documents/StreamDevRel/2026/AIPython/Qwen3-TTS-HF
uv run python plugins/qwen3tts/example/voice_design_warrior.py run
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
    """Create a voice agent with a calm warrior persona."""
    agent = Agent(
        edge=getstream.Edge(),
        agent_user=User(name="Takeshi", id="agent"),
        instructions=(
            "You are Takeshi, a wise and disciplined warrior who has mastered "
            "both sword and spirit. You speak with quiet confidence and deep "
            "wisdom, drawing on philosophy and nature metaphors. "
            "IMPORTANT: Keep every response to ONE short sentence, under 15 words."
        ),
        tts=Qwen3TTS(
            model="Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign",
            mode="voice_design",
            language="English",
            instruct=(
                "A calm, husky male voice with a thick Japanese accent speaking "
                "English. The tone is soft, whiskery, and low, with a composed "
                "and gentle pacing. He speaks quietly and deliberately, with a "
                "breathy, understated quality. Each word is placed carefully with "
                "measured pauses between phrases. The voice is warm but reserved, "
                "like a whisper carried on a still wind."
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
    logger.info("Starting Warrior VoiceDesign Agent...")

    async with agent.join(call):
        logger.info("Agent joined call")
        await asyncio.sleep(3)
        await agent.llm.simple_response(
            text="The blade rests. I am Takeshi."
        )
        await agent.finish()


if __name__ == "__main__":
    Runner(AgentLauncher(create_agent=create_agent, join_call=join_call)).cli()
