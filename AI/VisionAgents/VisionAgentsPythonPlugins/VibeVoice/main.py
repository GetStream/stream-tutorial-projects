"""VibeVoice TTS Plugin — Quick Start

Run the VibeVoice server first:
    python demo/vibevoice_realtime_demo.py \
        --model_path microsoft/VibeVoice-Realtime-0.5B --port 3000

Then run this script:
    python main.py run
"""

from dotenv import load_dotenv

load_dotenv()

from vision_agents.core import Agent, AgentLauncher, User, Runner
from vision_agents.plugins import getstream, openai, deepgram
from vision_agents.plugins import vibevoice


async def create_agent(**kwargs) -> Agent:
    return Agent(
        edge=getstream.Edge(),
        agent_user=User(name="Assistant", id="agent"),
        instructions="You are a helpful voice assistant. Be concise and conversational.",
        stt=deepgram.STT(),
        tts=vibevoice.TTS(voice="en-Emma_woman"),
        llm=openai.ChatCompletionsLLM(model="gpt-4o"),
    )


async def join_call(agent: Agent, call_type: str, call_id: str, **kwargs) -> None:
    call = await agent.create_call(call_type, call_id)
    async with agent.join(call):
        await agent.simple_response("Hello! How can I help you today?")
        await agent.finish()


if __name__ == "__main__":
    Runner(AgentLauncher(create_agent=create_agent, join_call=join_call)).cli()
