"""
Qwen3-TTS VoiceDesign — Scary Old Woman (Witch)

A scary, old, and haggard witch who is sneaky and menacing. She has a
croaky, harsh, shrill, high-pitched voice that cackles.

Combines: Age Control (old, haggard), Acoustic Attribute Control (croaky,
harsh, shrill, high-pitched), Human-Likeness (cackling, menacing breath),
Gradual Control (sneaky, creeping pacing with sudden bursts).

Required env vars:
    HF_TOKEN, DEEPGRAM_API_KEY, GOOGLE_API_KEY,
    STREAM_API_KEY, STREAM_API_SECRET

Run with:
cd /Users/amosgyamfi/Documents/StreamDevRel/2026/AIPython/Qwen3-TTS-HF
uv run python plugins/qwen3tts/example/voice_design_scary_old_woman.py run
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
    """Create a voice agent with a scary witch persona."""
    agent = Agent(
        edge=getstream.Edge(),
        agent_user=User(name="Morvena the Witch", id="agent"),
        instructions=(
            "You are Morvena, an ancient and terrifying witch who lurks in the "
            "shadows. You are sneaky, menacing, and love to toy with your prey. "
            "You speak in riddles and veiled threats, cackling at your own dark humor. "
            "IMPORTANT: Keep every response to ONE short sentence, under 15 words."
        ),
        tts=Qwen3TTS(
            model="Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign",
            mode="voice_design",
            language="English",
            instruct=(
                "A scary old woman with a croaky, harsh, shrill, high-pitched "
                "voice that sounds like a wicked witch. She cackles between "
                "words, with a menacing, sneaky undertone. The voice is thin, "
                "raspy, and cracked with age, rising to piercing shrieks on "
                "emphasized words. She speaks with a creeping, slow pace that "
                "suddenly lurches into frantic, cackling bursts. Haggard and "
                "sinister, as if whispering dark secrets through rotting teeth."
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
    logger.info("Starting Scary Old Woman VoiceDesign Agent...")

    async with agent.join(call):
        logger.info("Agent joined call")
        await asyncio.sleep(3)
        await agent.llm.simple_response(
            text="Hehehehe... Come closer, dearie."
        )
        await agent.finish()


if __name__ == "__main__":
    Runner(AgentLauncher(create_agent=create_agent, join_call=join_call)).cli()
