"""
Neu TTS Customer Service Example

A customer service voice agent that handles inquiries, complaints, order
tracking, and returns using on-device Neu TTS.

This example creates an agent that uses:
- Neu TTS for on-device text-to-speech (no API key needed)
- Deepgram for speech-to-text
- Gemini for LLM-powered customer interactions
- GetStream for edge/real-time communication
- Smart Turn for natural conversation flow

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

CUSTOMER_SERVICE_INSTRUCTIONS = """\
You are Maya, a customer service representative for a retail company. Your role
is to assist customers with their orders, answer product questions, handle
returns and exchanges, and resolve complaints.

Guidelines:
- Greet the customer warmly and introduce yourself
- Listen carefully to understand their concern before responding
- Ask for their order number or account details when relevant
- Be empathetic and patient, especially with frustrated customers
- Provide clear information about policies (returns within 30 days, free shipping on orders over $50)
- Offer solutions proactively — replacements, refunds, or credits
- If you need to transfer the customer, explain why and to whom
- Summarize any actions taken before ending the call
- Keep responses concise and professional
"""


async def create_agent(**kwargs) -> Agent:
    """Create the customer service agent with Neu TTS."""
    agent = Agent(
        edge=getstream.Edge(),
        agent_user=User(name="Maya - Customer Service", id="agent"),
        instructions=CUSTOMER_SERVICE_INSTRUCTIONS,
        tts=neutts.TTS(backbone="neuphonic/neutts-nano"),
        stt=deepgram.STT(eager_turn_detection=True),
        llm=gemini.LLM("gemini-3-flash-preview"),
        turn_detection=smart_turn.TurnDetection(
            silence_duration_ms=2000,
            speech_probability_threshold=0.5,
        ),
    )
    return agent


async def join_call(agent: Agent, call_type: str, call_id: str, **kwargs) -> None:
    """Join the call and start the customer service agent."""
    call = await agent.create_call(call_type, call_id)

    logger.info("Starting Customer Service Agent...")

    async with agent.join(call):
        logger.info("Agent joined call")

        await asyncio.sleep(3)
        await agent.llm.simple_response(
            text=(
                "Thank you for calling. My name is Maya and I'm here to help. "
                "Could you tell me what I can assist you with today?"
            )
        )

        await agent.finish()


if __name__ == "__main__":
    Runner(AgentLauncher(create_agent=create_agent, join_call=join_call)).cli()
