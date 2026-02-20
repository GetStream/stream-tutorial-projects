from vision_agents.core import Agent, Runner, User
from vision_agents.core.agents import AgentLauncher
from vision_agents.plugins import deepgram, gemini, getstream, elevenlabs


async def create_agent(**kwargs) -> Agent:
    return Agent(
        edge=getstream.Edge(),
        agent_user=User(name="Assistant", id="agent"),
        instructions="You're a helpful voice/vision AI assistant powered by Gemini 3.1 Pro. Keep replies short and conversational. Be concise and to the point. Always describe what you see in the user's video camera feed.",
        stt=deepgram.STT(eager_turn_detection=True),
        tts=elevenlabs.TTS(),
        llm=gemini.LLM("gemini-3.1-pro-preview"),
    )


async def join_call(agent: Agent, call_type: str, call_id: str, **kwargs) -> None:
    await agent.create_user()
    call = await agent.create_call(call_type, call_id)
    async with agent.join(call):
        await agent.simple_response("Greet the user")
        await agent.finish()


if __name__ == "__main__":
    Runner(AgentLauncher(create_agent=create_agent, join_call=join_call)).cli()
