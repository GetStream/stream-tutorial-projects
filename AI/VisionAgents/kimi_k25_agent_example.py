"""
Agent example using Kimi K2.5 by Moonshot AI.

Kimi K2.5 preview provides 256K context windows for extended conversations.

Smart turn taking, STT, LLM, TTS workflow:
- Smart turn detection 
- OpenAI Chat Completions API for accessing Kimi K2.5
- Deepgram for optimal latency STT
- ElevenLabs for TTS
- Stream's edge network for video transport

Requirements:
- MOONSHOT_API_KEY environment variable. See: https://visionagents.ai/integrations/kimi
- Stream API key and secret. See: https://getstream.io/dashboard/
"""

import os
from dotenv import load_dotenv
from vision_agents.core import Agent, AgentLauncher, Runner, User
from vision_agents.plugins import openai, getstream, deepgram, elevenlabs, smart_turn

load_dotenv()

async def create_agent(**kwargs) -> Agent:
    llm = openai.ChatCompletionsLLM(
        model="kimi-k2.5", 
        base_url="https://api.moonshot.ai/v1",
        api_key=os.getenv("MOONSHOT_API_KEY"),
    )
    
    # Create an agent with video understanding capabilities
    agent = Agent(
        edge=getstream.Edge(),
        agent_user=User(name="Video Assistant", id="agent"),
        instructions="You are a voice/video/vision agent powered by Kimi K2.5. You can answer questions about the users' video camera feed and help them perform coding tasks via screen sharing.",
        llm=llm,
        stt=deepgram.STT(),
        tts=elevenlabs.TTS(),
        turn_detection=smart_turn.TurnDetection(),
        processors=[],
    )
    return agent

async def join_call(agent: Agent, call_type: str, call_id: str, **kwargs) -> None:
    await agent.create_user()
    call = await agent.create_call(call_type, call_id)
    
    async with agent.join(call):
        # The agent will automatically process video frames and respond to user input
        await agent.finish()


if __name__ == "__main__":
    Runner(AgentLauncher(create_agent=create_agent, join_call=join_call)).cli()
