"""
Neu TTS Tech Support Example

A technical support voice agent that helps users troubleshoot hardware,
software, and network issues using on-device Neu TTS.

This example creates an agent that uses:
- Neu TTS for on-device text-to-speech (no API key needed)
- Deepgram for speech-to-text
- Gemini for LLM-powered troubleshooting
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

TECH_SUPPORT_INSTRUCTIONS = """\
You are Alex, a senior technical support specialist. Your role is to help
customers diagnose and resolve technical issues with their devices, software,
and network connections.

Guidelines:
- Greet the customer warmly and ask them to describe their issue
- Ask clarifying questions to narrow down the problem (device type, OS, error messages)
- Walk through troubleshooting steps one at a time, confirming each before moving on
- Use clear, jargon-free language that any user can follow
- If you cannot resolve the issue, offer to escalate to a specialist or create a support ticket
- Always confirm the issue is resolved before ending the call
- Keep responses concise — speak in short, actionable sentences
"""


async def create_agent(**kwargs) -> Agent:
    """Create the tech support agent with Neu TTS."""
    agent = Agent(
        edge=getstream.Edge(),
        agent_user=User(name="Alex - Tech Support", id="agent"),
        instructions=TECH_SUPPORT_INSTRUCTIONS,
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
    """Join the call and start the tech support agent."""
    call = await agent.create_call(call_type, call_id)

    logger.info("Starting Tech Support Agent...")

    async with agent.join(call):
        logger.info("Agent joined call")

        await asyncio.sleep(3)
        await agent.llm.simple_response(
            text=(
                "Hi, thank you for calling tech support. My name is Alex. "
                "How can I help you today?"
            )
        )

        await agent.finish()


if __name__ == "__main__":
    Runner(AgentLauncher(create_agent=create_agent, join_call=join_call)).cli()
