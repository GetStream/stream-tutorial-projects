import asyncio
import io
import os
import platform
import warnings
import wave

from google import genai
from google.genai import types

warnings.filterwarnings("ignore", message=".*experimental.*")

SAMPLE_RATE = 48000
CHANNELS = 2
DURATION_SECONDS = 30
CHUNK_DURATION = 2
OUTPUT_DIR = "generated_music"

client = genai.Client(http_options={"api_version": "v1alpha"})


async def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    audio_buffer = io.BytesIO()
    max_chunks = DURATION_SECONDS // CHUNK_DURATION
    chunk_count = 0

    print(f"Generating {DURATION_SECONDS}s of minimal techno at 90 BPM...")

    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        async with client.aio.live.music.connect(model="models/lyria-realtime-exp") as session:
            await session.set_weighted_prompts(
                prompts=[
                    types.WeightedPrompt(text="minimal techno", weight=1.0),
                ]
            )
            await session.set_music_generation_config(
                config=types.LiveMusicGenerationConfig(bpm=90, temperature=1.0)
            )

            await session.play()

            async for message in session.receive():
                if chunk_count >= max_chunks:
                    break

                try:
                    server_content = getattr(message, "server_content", None)
                    if server_content is None:
                        continue
                    audio_chunks = getattr(server_content, "audio_chunks", None)
                    if not audio_chunks:
                        continue
                    audio_data = audio_chunks[0].data
                    if audio_data is None:
                        continue
                except (AttributeError, IndexError, TypeError):
                    continue

                audio_buffer.write(audio_data)
                chunk_count += 1
                print(f"  Chunk {chunk_count}/{max_chunks} ({len(audio_data)} bytes)")

    output_path = os.path.join(OUTPUT_DIR, "quick_start_minimal_techno_90bpm.wav")
    with wave.open(output_path, "wb") as wf:
        wf.setnchannels(CHANNELS)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(audio_buffer.getvalue())

    print(f"Saved to {output_path}")

    system = platform.system()
    if system == "Darwin":
        cmd = ["afplay", output_path]
    elif system == "Linux":
        cmd = ["aplay", output_path]
    else:
        print("Auto-play not supported on this platform. Open the WAV file manually.")
        return

    print("Playing...")
    proc = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.DEVNULL,
        stderr=asyncio.subprocess.DEVNULL,
    )
    await proc.communicate()


if __name__ == "__main__":
    asyncio.run(main())
