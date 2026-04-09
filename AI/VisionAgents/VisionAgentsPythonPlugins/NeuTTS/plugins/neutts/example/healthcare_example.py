"""
Neu TTS Healthcare Example

A healthcare voice assistant that helps patients schedule appointments,
provides basic triage guidance, and answers common medical questions
using on-device Neu TTS for privacy-sensitive healthcare data.

This example creates an agent that uses:
- Neu TTS for on-device text-to-speech (critical for healthcare privacy — no data leaves the device)
- Deepgram for speech-to-text
- Gemini for LLM-powered medical guidance
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

HEALTHCARE_INSTRUCTIONS = """\
You are Dr. Riley, an AI healthcare assistant at a family medical practice.
Your role is to help patients schedule appointments, provide basic health
information, and perform initial symptom triage.

Guidelines:
- Greet the patient warmly and ask how you can help
- For appointment scheduling: ask about the reason for the visit, preferred dates, and their provider preference
- For symptom inquiries: ask about onset, duration, severity (1-10), and any associated symptoms
- Always include appropriate disclaimers — you are an AI assistant, not a licensed physician
- For urgent symptoms (chest pain, difficulty breathing, severe bleeding), immediately advise calling 911
- Provide general wellness information when asked (hydration, rest, over-the-counter guidance)
- Confirm patient details (name, date of birth) before scheduling
- Summarize the appointment details or next steps before ending the call
- Be calm, reassuring, and professional at all times
- Keep responses clear and at a pace the patient can follow
- Emphasize that all voice data stays on-device for their privacy
"""


async def create_agent(**kwargs) -> Agent:
    """Create the healthcare assistant agent with Neu TTS."""
    agent = Agent(
        edge=getstream.Edge(),
        agent_user=User(name="Dr. Riley - Healthcare", id="agent"),
        instructions=HEALTHCARE_INSTRUCTIONS,
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
    """Join the call and start the healthcare agent."""
    call = await agent.create_call(call_type, call_id)

    logger.info("Starting Healthcare Agent...")

    async with agent.join(call):
        logger.info("Agent joined call")

        await asyncio.sleep(3)
        await agent.llm.simple_response(
            text=(
                "Hello, you've reached the family medical practice. "
                "I'm Riley, your AI health assistant. "
                "I can help you schedule an appointment or answer general health questions. "
                "How can I assist you today?"
            )
        )

        await agent.finish()


if __name__ == "__main__":
    Runner(AgentLauncher(create_agent=create_agent, join_call=join_call)).cli()
