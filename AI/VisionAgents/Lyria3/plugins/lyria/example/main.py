"""Example: Lyria 3 Music Generator Agent with Vision Agents.

This agent generates 30-second instrumental music tracks based on voice prompts.
Uses Gemini Realtime for native speech-to-speech with optional video.

Run from the project root:
    uv run main.py run

Environment variables needed:
    - GOOGLE_API_KEY (for Gemini Realtime + Lyria RealTime)
    - STREAM_API_KEY and STREAM_API_SECRET (for Stream Video)
"""

import asyncio

from vision_agents.core import Agent, AgentLauncher, Runner, User
from vision_agents.plugins import gemini, getstream
from vision_agents.plugins.lyria import MusicProcessor


async def create_agent(**kwargs) -> Agent:
    processor = MusicProcessor(
        initial_prompt="Ambient chill music",
        bpm=90,
        density=0.5,
        brightness=0.5,
        duration_seconds=30,
    )

    llm = gemini.Realtime(fps=3)

    @llm.register_function(
        description="Generate a 30-second music track based on the user's description. "
        "Use descriptive terms like genre, instruments, mood, and tempo. "
        "Returns immediately while music generates in the background."
    )
    async def generate_music(prompt: str) -> str:
        await processor.generate_music_async(prompt=prompt)
        return f"Music generation started for: {prompt}. It will be saved to the generated_music folder when complete (~30 seconds)."

    @llm.register_function(
        description="Change the music style/genre for future generations."
    )
    async def change_music_style(prompt: str) -> str:
        await processor.update_prompt(prompt)
        return f"Music style changed to: {prompt}"

    @llm.register_function(
        description="Adjust the tempo (BPM) of the music. Range: 40-180."
    )
    async def set_tempo(bpm: int) -> str:
        await processor.set_config(bpm=bpm)
        return f"Tempo set to {bpm} BPM"

    return Agent(
        edge=getstream.Edge(),
        agent_user=User(name="Music Generator", id="lyria-music-agent"),
        instructions=(
            "You are a music-generating AI assistant powered by Google's Lyria 3. "
            "When users describe the kind of music they want, use the generate_music "
            "function to create a 30-second instrumental track. You can also adjust "
            "the tempo and style. Keep your responses friendly and musical. "
            "Describe what you're generating before starting."
        ),
        llm=llm,
        processors=[processor],
    )


async def join_call(agent: Agent, call_type: str, call_id: str, **kwargs) -> None:
    call = await agent.create_call(call_type, call_id)
    async with agent.join(call):
        await agent.finish()


Runner(AgentLauncher(create_agent=create_agent, join_call=join_call)).cli()
