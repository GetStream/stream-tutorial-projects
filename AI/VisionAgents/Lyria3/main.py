"""Lyria 3 Music Generator - Vision Agents Plugin.

Generates 30-second instrumental music tracks from voice prompts
using Google's Lyria RealTime API integrated with Vision Agents.

Run from the project root:
    uv run main.py run

Set GOOGLE_API_KEY in your .env file before running.
"""

import asyncio

from vision_agents.core import Agent, AgentLauncher, Runner, User
from vision_agents.plugins import gemini, getstream

from plugins.lyria.vision_agents.plugins.lyria import MusicProcessor


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
        description="Generate a 30-second instrumental music track. "
        "Accepts a text prompt describing the desired genre, instruments, mood, or style. "
        "Returns immediately while music generates in the background."
    )
    async def generate_music(prompt: str) -> str:
        await processor.generate_music_async(prompt=prompt)
        return f"Music generation started for: {prompt}. It will be saved to the generated_music folder when complete (~30 seconds)."

    @llm.register_function(
        description="Change the music style for the next generation."
    )
    async def change_music_style(prompt: str) -> str:
        await processor.update_prompt(prompt)
        return f"Music style changed to: {prompt}"

    @llm.register_function(
        description="Set the tempo (beats per minute) for music generation. Range: 40-180."
    )
    async def set_tempo(bpm: int) -> str:
        await processor.set_config(bpm=bpm)
        return f"Tempo set to {bpm} BPM"

    @llm.register_function(
        description="Blend two music styles with weights (0.0-1.0). "
        "Example: style1='Jazz', weight1=0.7, style2='Electronic', weight2=0.3"
    )
    async def blend_styles(
        style1: str, weight1: float, style2: str, weight2: float
    ) -> str:
        prompts = [
            {"text": style1, "weight": weight1},
            {"text": style2, "weight": weight2},
        ]
        await processor.set_weighted_prompts(prompts)
        return f"Blending styles: {style1}:{weight1}, {style2}:{weight2}"

    return Agent(
        edge=getstream.Edge(),
        agent_user=User(name="Music Generator", id="lyria-music-agent"),
        instructions=(
            "You are a music-generating AI assistant powered by Google's Lyria 3. "
            "When users describe the kind of music they want, use the generate_music "
            "function to create a 30-second instrumental track. You can also adjust "
            "the tempo with set_tempo, change the style with change_music_style, or "
            "blend multiple styles with blend_styles. Keep your responses friendly. "
            "Describe what you're generating before calling the function."
        ),
        llm=llm,
        processors=[processor],
    )


async def join_call(agent: Agent, call_type: str, call_id: str, **kwargs) -> None:
    call = await agent.create_call(call_type, call_id)
    async with agent.join(call):
        await agent.finish()


Runner(AgentLauncher(create_agent=create_agent, join_call=join_call)).cli()
