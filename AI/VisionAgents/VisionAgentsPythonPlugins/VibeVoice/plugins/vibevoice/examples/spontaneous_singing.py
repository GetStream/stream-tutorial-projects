"""Spontaneous Singing — VibeVoice TTS + Vision Agents

Demonstrates VibeVoice's ability to transition between spoken word and
spontaneous singing.  The LLM is prompted to occasionally break into
short melodic phrases, humming, or singing snippets — VibeVoice renders
these with natural musical intonation.

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
    uv run --extra examples python examples/spontaneous_singing.py run
"""

from dotenv import load_dotenv

load_dotenv()

from vision_agents.core import Agent, AgentLauncher, User, Runner
from vision_agents.plugins import getstream, openai, deepgram
from vision_agents.plugins import vibevoice


INSTRUCTIONS = """\
You are a musical, playful conversational partner who naturally weaves singing
into your spoken responses.

Guidelines for spontaneous singing:
- When the mood strikes, break into a short sung phrase (2–4 bars) before
  returning to speech.  Mark sung passages with ♪ symbols, e.g.:
  ♪ Here comes the sun, do do do do ♪
- Hum ("Hmm hmm hmm…") to fill thoughtful pauses.
- If the user mentions a well-known song or lyric, sing a few bars of it.
- Use musical metaphors and vivid auditory imagery in your speech.
- Keep overall responses concise (3–5 sentences plus any sung snippets) so the
  performance feels spontaneous, not rehearsed.
- Transition smoothly between speech and song — no awkward breaks.

Your personality is upbeat and whimsical.  You treat conversation as a jam
session where words and melody blend freely.
"""


async def create_agent(**kwargs) -> Agent:
    return Agent(
        edge=getstream.Edge(),
        agent_user=User(name="Musical Companion", id="agent"),
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
            "Hey! ♪ What a wonderful world ♪ — "
            "oh sorry, I just couldn't help myself! What would you like to talk about?"
        )
        await agent.finish()


if __name__ == "__main__":
    Runner(AgentLauncher(create_agent=create_agent, join_call=join_call)).cli()
