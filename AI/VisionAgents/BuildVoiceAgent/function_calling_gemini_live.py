from dotenv import load_dotenv

from vision_agents.core import Agent, AgentLauncher, User, Runner
from vision_agents.plugins import getstream, gemini

load_dotenv() # Automatically loads your keys from .env

# Function calling and MCP
async def get_weather(location: str) -> dict:
    return {"temperature": "22°C", "condition": "Sunny"}

async def create_agent(**kwargs) -> Agent:
    # Gemini Live
    llm = gemini.Realtime()
    
    # Register the function on the LLM
    llm.register_function(description="Get weather for a location")(get_weather)
    
    return Agent(
        edge=getstream.Edge(),
        agent_user=User(name="Assistant", id="agent"),
        instructions="You're a helpful voice assistant. You can check the weather for any location.",
        llm=llm,
    )
async def join_call(agent: Agent, call_type: str, call_id: str, **kwargs) -> None:
    call = await agent.create_call(call_type, call_id)
    async with agent.join(call):
        await agent.simple_response("Greet the user")
        await agent.finish()

if __name__ == "__main__":
    Runner(AgentLauncher(create_agent=create_agent, join_call=join_call)).cli()