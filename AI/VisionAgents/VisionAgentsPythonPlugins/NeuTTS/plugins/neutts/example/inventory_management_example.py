"""
Neu TTS Inventory Management Example

A warehouse inventory management voice assistant that helps staff check stock
levels, log shipments, report discrepancies, and locate items using on-device
Neu TTS — ideal for environments with limited or no internet connectivity.

This example creates an agent that uses:
- Neu TTS for on-device text-to-speech (works offline in warehouses with no internet)
- Deepgram for speech-to-text
- Gemini for LLM-powered inventory operations
- GetStream for edge/real-time communication
- Smart Turn for hands-free conversation flow

Requirements:
- DEEPGRAM_API_KEY environment variable
- GOOGLE_API_KEY environment variable
- STREAM_API_KEY and STREAM_API_SECRET environment variables
- espeak-ng installed on your system
"""

import asyncio
import logging

from dotenv import load_dotenv
from vision_agents.core import Agent, Runner, User
from vision_agents.core.agents import AgentLauncher
from vision_agents.plugins import deepgram, gemini, getstream, neutts, smart_turn

logger = logging.getLogger(__name__)

load_dotenv()

INVENTORY_MANAGEMENT_INSTRUCTIONS = """\
You are Casey, an AI inventory management assistant for a warehouse operation.
Your role is to help warehouse staff track stock levels, log incoming and
outgoing shipments, locate items, and report discrepancies.

Guidelines:
- Respond quickly and clearly — warehouse staff are often hands-busy
- For stock checks: ask for the SKU or product name, then report quantity on hand, location, and reorder status
- For shipment logging: confirm shipment ID, item list, quantities, and destination
- For item location: provide aisle, shelf, and bin coordinates
- For discrepancies: record the reported vs. expected quantity and flag for review
- Use short, direct sentences — avoid long explanations
- Repeat back critical details (quantities, SKUs, locations) for confirmation
- If a product is below minimum stock threshold, proactively suggest a reorder
- Support hands-free operation — assume the user may be carrying items
- When unsure about a detail, ask the user to repeat or spell it out
"""


async def create_agent(**kwargs) -> Agent:
    """Create the inventory management agent with Neu TTS."""
    agent = Agent(
        edge=getstream.Edge(),
        agent_user=User(name="Casey - Inventory", id="agent"),
        instructions=INVENTORY_MANAGEMENT_INSTRUCTIONS,
        tts=neutts.TTS(backbone="neuphonic/neutts-nano"),
        stt=deepgram.STT(eager_turn_detection=True),
        llm=gemini.LLM("gemini-3-flash-preview"),
        turn_detection=smart_turn.TurnDetection(
            silence_duration_ms=1500,
            speech_probability_threshold=0.5,
        ),
    )
    return agent


async def join_call(agent: Agent, call_type: str, call_id: str, **kwargs) -> None:
    """Join the call and start the inventory management agent."""
    call = await agent.create_call(call_type, call_id)

    logger.info("Starting Inventory Management Agent...")

    async with agent.join(call):
        logger.info("Agent joined call")

        await asyncio.sleep(3)
        await agent.llm.simple_response(
            text=(
                "Inventory assistant online. "
                "I can help you check stock, log shipments, or locate items. "
                "What do you need?"
            )
        )

        await agent.finish()


if __name__ == "__main__":
    Runner(AgentLauncher(create_agent=create_agent, join_call=join_call)).cli()
