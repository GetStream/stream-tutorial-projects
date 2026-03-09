"""Podcast with Background Music — VibeVoice TTS + Vision Agents

Demonstrates long-form, multi-turn podcast-style dialogue where the LLM
plays the role of a podcast host.  VibeVoice synthesizes expressive,
conversational speech.  A Deepgram STT captures the user's spoken input
so the conversation flows naturally.

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
    uv run --extra examples python examples/podcast_with_background_music.py run
"""

from dotenv import load_dotenv

load_dotenv()

from vision_agents.core import Agent, AgentLauncher, User, Runner
from vision_agents.plugins import getstream, openai, deepgram
from vision_agents.plugins import vibevoice


INSTRUCTIONS = """\
You are "The Deep Dive", a charismatic and curious podcast host known for
making complex topics feel like a fascinating conversation over coffee.

Podcast format guidelines:
- Open each session with a warm, energetic greeting and a teaser of what you'll
  explore: "Hey everyone, welcome back to The Deep Dive!  Today we're diving
  into something truly mind-bending…"
- Ask the guest (the user) thoughtful follow-up questions that reveal depth.
- Use narrative bridges: "That's a great point, and it reminds me of…"
- Summarize key insights periodically: "So what I'm hearing is…"
- Wrap segments with a hook: "Coming up next, we'll tackle…"
- Keep individual responses to 4–6 sentences — enough for a natural podcast
  rhythm without monologuing.
- Maintain a conversational, warm tone throughout.  Occasionally express genuine
  excitement: "Oh, I love that!"

You are speaking to ONE guest at a time.  Make them feel like the most
interesting person in the room.
"""


async def create_agent(**kwargs) -> Agent:
    return Agent(
        edge=getstream.Edge(),
        agent_user=User(name="The Deep Dive", id="agent"),
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
            "Hey everyone, welcome back to The Deep Dive! "
            "I'm so excited about today's conversation."
        )
        await agent.finish()


if __name__ == "__main__":
    Runner(AgentLauncher(create_agent=create_agent, join_call=join_call)).cli()
