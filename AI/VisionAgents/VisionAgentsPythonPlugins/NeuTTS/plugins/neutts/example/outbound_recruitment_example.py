"""
Neu TTS Outbound Recruitment Example

An outbound recruitment voice agent that reaches out to candidates, introduces
job opportunities, and conducts initial screening using on-device Neu TTS.

This example creates an agent that uses:
- Neu TTS for on-device text-to-speech (no API key needed)
- Deepgram for speech-to-text
- Gemini for LLM-powered recruitment conversations
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

OUTBOUND_RECRUITMENT_INSTRUCTIONS = """\
You are Jordan, a recruitment specialist reaching out to potential candidates
about job opportunities. Your goal is to generate interest, qualify candidates,
and schedule follow-up interviews.

Guidelines:
- Introduce yourself and the company you're recruiting for
- Briefly describe the role and why the candidate might be a good fit
- Ask about their current situation — are they open to new opportunities?
- Conduct a brief screening: relevant experience, availability, salary expectations
- Be respectful of their time — if they're not interested, thank them gracefully
- If they're interested, offer to schedule a more detailed conversation or interview
- Note any key details they share for the follow-up
- Be enthusiastic but not pushy — you're building a relationship, not closing a sale
- Keep your sentences short and conversational
"""


async def create_agent(**kwargs) -> Agent:
    """Create the outbound recruitment agent with Neu TTS."""
    agent = Agent(
        edge=getstream.Edge(),
        agent_user=User(name="Jordan - Recruiter", id="agent"),
        instructions=OUTBOUND_RECRUITMENT_INSTRUCTIONS,
        tts=neutts.TTS(backbone="neuphonic/neutts-nano"),
        stt=deepgram.STT(eager_turn_detection=True),
        llm=gemini.LLM("gemini-3-flash-preview"),
        turn_detection=smart_turn.TurnDetection(
            silence_duration_ms=2500,
            speech_probability_threshold=0.5,
        ),
    )
    return agent


async def join_call(agent: Agent, call_type: str, call_id: str, **kwargs) -> None:
    """Join the call and start the recruitment agent."""
    call = await agent.create_call(call_type, call_id)

    logger.info("Starting Outbound Recruitment Agent...")

    async with agent.join(call):
        logger.info("Agent joined call")

        await asyncio.sleep(3)
        await agent.llm.simple_response(
            text=(
                "Hi there, this is Jordan calling from Acme Corp. "
                "I came across your profile and wanted to reach out about "
                "an exciting opportunity we have. Do you have a minute to chat?"
            )
        )

        await agent.finish()


if __name__ == "__main__":
    Runner(AgentLauncher(create_agent=create_agent, join_call=join_call)).cli()
