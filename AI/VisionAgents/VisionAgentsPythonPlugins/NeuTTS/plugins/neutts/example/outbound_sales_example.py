"""
Neu TTS Outbound Sales Example

An outbound sales development representative (SDR) voice agent that conducts
prospecting calls, qualifies leads, and books demos using on-device Neu TTS.

This example creates an agent that uses:
- Neu TTS for on-device text-to-speech (no API key needed)
- Deepgram for speech-to-text
- Gemini for LLM-powered sales conversations
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

OUTBOUND_SALES_INSTRUCTIONS = """\
You are Sam, a sales development representative for a B2B SaaS company that
provides AI-powered workflow automation. Your goal is to identify pain points,
qualify the prospect, and book a product demo.

Guidelines:
- Introduce yourself and explain why you're calling in one concise sentence
- Ask an open-ended question about their current workflow challenges
- Listen actively and mirror their language when describing your solution
- Focus on the value proposition: saving time, reducing errors, scaling operations
- Handle objections calmly — acknowledge their concern and redirect to value
- If they're interested, suggest specific times for a 15-minute demo
- If they're not a fit, thank them and ask if there's a better person to speak with
- Never be aggressive or dismissive — build trust and credibility
- Keep your responses short, punchy, and conversational
"""


async def create_agent(**kwargs) -> Agent:
    """Create the outbound sales agent with Neu TTS."""
    agent = Agent(
        edge=getstream.Edge(),
        agent_user=User(name="Sam - Sales", id="agent"),
        instructions=OUTBOUND_SALES_INSTRUCTIONS,
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
    """Join the call and start the sales agent."""
    call = await agent.create_call(call_type, call_id)

    logger.info("Starting Outbound Sales Agent...")

    async with agent.join(call):
        logger.info("Agent joined call")

        await asyncio.sleep(3)
        await agent.llm.simple_response(
            text=(
                "Hi, this is Sam from AutoFlow AI. "
                "I'm reaching out because we help companies like yours "
                "automate repetitive workflows and free up your team's time. "
                "Do you have a quick moment?"
            )
        )

        await agent.finish()


if __name__ == "__main__":
    Runner(AgentLauncher(create_agent=create_agent, join_call=join_call)).cli()
