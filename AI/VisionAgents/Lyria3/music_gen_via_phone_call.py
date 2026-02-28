import asyncio
import logging
import os
import uuid

import click
import uvicorn
from dotenv import load_dotenv
from fastapi import FastAPI, WebSocket
from twilio.rest import Client

from vision_agents.core import Agent, User
from vision_agents.plugins import gemini, getstream, twilio

from plugins.lyria.vision_agents.plugins.lyria import MusicProcessor

load_dotenv()

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)

NGROK_URL = os.environ["NGROK_URL"].replace("https://", "").replace("http://", "").rstrip("/")

app = FastAPI()
call_registry = twilio.TwilioCallRegistry()


async def create_agent() -> Agent:
    processor = MusicProcessor(
        initial_prompt="Ambient chill music",
        bpm=90,
        density=0.5,
        brightness=0.5,
        duration_seconds=30,
    )

    llm = gemini.Realtime()

    @llm.register_function(
        description="Generate a 30-second instrumental music track. "
        "Accepts a voice prompt describing the desired genre, instruments, mood, or style. "
        "Returns immediately while music generates in the background."
    )
    async def generate_music(prompt: str) -> str:
        await processor.generate_music_async(prompt=prompt)
        return (
            f"Music generation started for: {prompt}. "
            "The track will be ready in about 30 seconds and will play automatically."
        )

    @llm.register_function(
        description="Change the music style for the next generation."
    )
    async def change_music_style(prompt: str) -> str:
        await processor.update_prompt(prompt)
        return f"Music style changed to: {prompt}"

    @llm.register_function(
        description="Set the tempo (beats per minute) for music generation. Range: 40-180."
    )
    async def set_tempo(bpm: int) -> str:
        await processor.set_config(bpm=bpm)
        return f"Tempo set to {bpm} BPM"

    @llm.register_function(
        description="Blend two music styles with weights (0.0-1.0). "
        "Example: style1='Jazz', weight1=0.7, style2='Electronic', weight2=0.3"
    )
    async def blend_styles(
        style1: str, weight1: float, style2: str, weight2: float
    ) -> str:
        prompts = [
            {"text": style1, "weight": weight1},
            {"text": style2, "weight": weight2},
        ]
        await processor.set_weighted_prompts(prompts)
        return f"Blending styles: {style1}:{weight1}, {style2}:{weight2}"

    return Agent(
        edge=getstream.Edge(),
        agent_user=User(id="ai-agent", name="Lyria Music Agent"),
        instructions=(
            "You are a music-generating AI assistant on a phone call, powered by "
            "Google's Lyria 3. When the user describes the kind of music they want, "
            "use the generate_music function to create a 30-second instrumental track. "
            "You can also adjust the tempo with set_tempo, change the style with "
            "change_music_style, or blend two styles with blend_styles. "
            "Start by greeting the caller and asking what kind of music they'd like. "
            "Keep your responses concise and friendly — this is a phone call."
        ),
        llm=llm,
        processors=[processor],
    )


async def initiate_outbound_call(from_number: str, to_number: str) -> str:
    """Initiate an outbound call via Twilio. Returns the call_id."""
    twilio_client = Client(
        os.environ["TWILIO_ACCOUNT_SID"], os.environ["TWILIO_AUTH_TOKEN"]
    )

    call_id = str(uuid.uuid4())

    async def prepare_call():
        agent = await create_agent()
        phone_user = User(name=f"Outbound call {call_id[:8]}", id=f"phone-{call_id}")

        await agent.edge.create_users([agent.agent_user, phone_user])
        agent.edge.agent_user_id = agent.agent_user.id

        stream_call = await agent.create_call("default", call_id)
        logger.info("prepared the call, ready to start")
        return agent, phone_user, stream_call

    twilio_call = call_registry.create(call_id, prepare=prepare_call)
    url = f"wss://{NGROK_URL}/twilio/media/{call_id}/{twilio_call.token}"
    logger.info(
        f"Forwarding to media url: {url} \n %s", twilio.create_media_stream_twiml(url)
    )

    twilio_client.calls.create(
        twiml=twilio.create_media_stream_twiml(url),
        to=to_number,
        from_=from_number,
    )
    logger.info(f"📞 Initiated call {call_id} from {from_number} to {to_number}")
    return call_id


@app.websocket("/twilio/media/{call_sid}/{token}")
async def media_stream(websocket: WebSocket, call_sid: str, token: str):
    twilio_call = call_registry.validate(call_sid, token)

    logger.info(f"🔗 Media stream connected for call {call_sid}")

    twilio_stream = twilio.TwilioMediaStream(websocket)
    await twilio_stream.accept()
    twilio_call.twilio_stream = twilio_stream

    try:
        (
            agent,
            phone_user,
            stream_call,
        ) = await twilio_call.await_prepare()
        twilio_call.stream_call = stream_call

        await twilio.attach_phone_to_call(stream_call, twilio_stream, phone_user.id)

        async with agent.join(stream_call, participant_wait_timeout=0):
            await agent.llm.simple_response(
                text="Greet the caller and ask what kind of music they'd like you to generate."
            )
            await twilio_stream.run()
    finally:
        call_registry.remove(call_sid)


async def run_with_server(from_number: str, to_number: str):
    """Start the server and initiate the outbound call once ready."""
    config = uvicorn.Config(app, host="localhost", port=8000, log_level="info")
    server = uvicorn.Server(config)

    server_task = asyncio.create_task(server.serve())

    while not server.started:
        await asyncio.sleep(0.1)

    logger.info("🚀 Server ready, initiating outbound call...")

    await initiate_outbound_call(from_number, to_number)

    await server_task


@click.command()
@click.option(
    "--from",
    "from_number",
    required=True,
    help="The Twilio phone number to call from (must be active in your Twilio account)",
)
@click.option("--to", "to_number", required=True, help="The phone number to call")
def main(from_number: str, to_number: str):
    logger.info(
        "Starting Lyria music generator outbound call. "
        "Note: latency is higher in dev. Deploy to US east for low latency."
    )
    asyncio.run(run_with_server(from_number, to_number))


if __name__ == "__main__":
    main()
