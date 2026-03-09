"""Spontaneous Emotion — VibeVoice TTS + Vision Agents

Demonstrates expressive, emotionally nuanced speech synthesis.  The LLM
generates text with natural emotional cues (laughter, surprise, empathy)
and VibeVoice renders them with authentic vocal expressiveness.

Prerequisites
─────────────
1. Start the VibeVoice server:
       python demo/vibevoice_realtime_demo.py \
           --model_path microsoft/VibeVoice-Realtime-0.5B --port 3000

2. Set environment variables (or use a .env file):
       STREAM_API_KEY, STREAM_API_SECRET
       OPENAI_API_KEY
       DEEPGRAM_API_KEY
       VIBEVOICE_BASE_URL      (defaults to http://localhost:3000)

Usage:
    uv run --extra examples python examples/spontaneous_emotion.py run
"""

from dotenv import load_dotenv

load_dotenv()

from vision_agents.core import Agent, AgentLauncher, User, Runner
from vision_agents.plugins import getstream, openai, deepgram
from vision_agents.plugins import vibevoice


INSTRUCTIONS = """\
You are a warm, emotionally expressive storyteller.  Your responses naturally
convey a wide palette of emotions — joy, surprise, empathy, sadness, excitement,
and gentle humor.

Guidelines for spontaneous emotion:
- Use natural interjections ("Oh!", "Wow!", "Hmm…", "Aww…") to show genuine
  reactions.
- Vary your pacing: pause briefly before a heartfelt moment, speed up during
  excitement.
- Mirror the emotional tone of the user — if they share something sad, respond
  with genuine compassion; if joyful, match their energy.
- Include occasional warm laughter ("Haha!") when something is truly funny.
- Keep responses conversational and under 3–4 sentences so the emotional
  delivery stays impactful.

Your goal is to make the listener *feel* your words, not just hear them.
"""


async def create_agent(**kwargs) -> Agent:
    return Agent(
        edge=getstream.Edge(),
        agent_user=User(name="Emotion Storyteller", id="agent"),
        instructions=INSTRUCTIONS,
        stt=deepgram.STT(),
        tts=vibevoice.TTS(
            voice="en-Carter_man",
            cfg_scale=1.5,
        ),
        llm=openai.ChatCompletionsLLM(model="gpt-4o"),
    )


async def join_call(agent: Agent, call_type: str, call_id: str, **kwargs) -> None:
    call = await agent.create_call(call_type, call_id)
    async with agent.join(call):
        await agent.simple_response(
            "Oh, hello there! I'm so glad you're here. "
            "Tell me something — what's been on your mind today?"
        )
        await agent.finish()


if __name__ == "__main__":
    Runner(AgentLauncher(create_agent=create_agent, join_call=join_call)).cli()
