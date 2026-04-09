"""
Qwen3-TTS Voice Clone (0.6B Base) + Vision Agents

Uses the smaller Qwen/Qwen3-TTS-12Hz-0.6B-Base model for voice cloning
in resource-constrained environments. Supports 3-second rapid voice clone
from any audio input.

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

REF_AUDIO_URL = (
    "https://qianwen-res.oss-cn-beijing.aliyuncs.com/Qwen3-TTS-Repo/clone.wav"
)
REF_TEXT = (
    "Okay. Yeah. I resent you. I love you. I respect you. "
    "But you know what? You blew it! And thanks to you."
)


async def create_agent(**kwargs) -> Agent:
    """Create a voice agent with Qwen3-TTS 0.6B Base — lightweight voice cloning."""
    tts_plugin = Qwen3TTS(
        model="Qwen/Qwen3-TTS-12Hz-0.6B-Base",
        mode="voice_clone",
        language="English",
        ref_audio=REF_AUDIO_URL,
        ref_text=REF_TEXT,
    )

    agent = Agent(
        edge=getstream.Edge(),
        agent_user=User(name="Qwen3 TTS AI", id="agent"),
        instructions=(
            "You are a helpful voice assistant with a cloned voice. "
            "Keep responses brief and conversational."
        ),
        tts=tts_plugin,
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
    logger.info("Starting Qwen3-TTS Voice Clone 0.6B Agent...")

    async with agent.join(call):
        logger.info("Agent joined call")
        await agent.tts.prepare_voice_clone_prompt()

        await asyncio.sleep(3)
        await agent.llm.simple_response(
            text="Hi! I'm using the lightweight 0.6B model for voice cloning."
        )
        await agent.finish()


if __name__ == "__main__":
    Runner(AgentLauncher(create_agent=create_agent, join_call=join_call)).cli()
