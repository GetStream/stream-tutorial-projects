"""Video analysis agent using Ollama (qwen3.5:9b).

Run from the project root so the installed vision_agents is used, e.g.:
    uv run python plugins/ollama/video_analysis_agent.py run
"""
import logging
from pathlib import Path

from dotenv import load_dotenv

from vision_agents.core import Agent, AgentLauncher, User, Runner
from vision_agents.plugins import getstream, deepgram, elevenlabs, smart_turn
from vision_agents.plugins.ollama import VLM as OllamaVLM

# Load .env from project root so STREAM_* and other keys are always found
_project_root = Path(__file__).resolve().parent.parent.parent
load_dotenv(_project_root / ".env")

logger = logging.getLogger(__name__)


def create_agent(**kwargs) -> Agent:
    """Create a video analysis agent using Ollama with qwen3.5:9b."""
    agent = Agent(
        edge=getstream.Edge(),
        agent_user=User(name="Video Analyst", id="agent"),
        instructions=(
            "You are a video analysis assistant. Analyze the video feed and "
            "answer questions about what you see. Be detailed and descriptive "
            "in your observations."
        ),
        llm=OllamaVLM(
            model="qwen3.5:9b",
            fps=1,
            frame_buffer_seconds=10,
        ),
        stt=deepgram.STT(),
        tts=elevenlabs.TTS(),
        turn_detection=smart_turn.TurnDetection(),
    )
    agent._audio_buffer_limit_ms = 90_000
    return agent


async def join_call(agent: Agent, call_type: str, call_id: str, **kwargs) -> None:
    """Join a call and start video analysis."""
    try:
        await agent.create_user()
        call = await agent.create_call(call_type, call_id)
        async with agent.join(call):
            await agent.simple_response("Tell the user a story about the video.")
            await agent.finish()
    except Exception as e:  # noqa: BLE001
        from getstream.video.rtc.connection_utils import SfuConnectionError

        if isinstance(e, SfuConnectionError):
            cause = e.__cause__ or e
            logger.error(
                "GetStream SFU connection failed: %s. Check STREAM_API_KEY and "
                "STREAM_API_SECRET in .env, and that your network allows WebRTC.",
                cause,
            )
        raise


if __name__ == "__main__":
    Runner(AgentLauncher(create_agent=create_agent, join_call=join_call)).cli()
