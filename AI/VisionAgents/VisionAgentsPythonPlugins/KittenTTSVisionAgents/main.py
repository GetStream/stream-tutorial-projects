"""
KittenTTS Vision Agents Plugin

Quick demo: synthesize speech locally with KittenTTS and save to a WAV file.
"""

import asyncio
from vision_agents.plugins.kittentts import TTS


async def main():
    tts = TTS(
        model="KittenML/kitten-tts-mini-0.8",
        voice="Bella",
    )

    await tts.warmup()

    pcm = await tts.stream_audio("Hello from KittenTTS! This is an ultra-lightweight text-to-speech model.")

    wav_bytes = pcm.to_wav_bytes()
    with open("output.wav", "wb") as f:
        f.write(wav_bytes)
    print(f"Audio saved to output.wav ({len(pcm.samples)} samples at {pcm.sample_rate}Hz)")

    await tts.close()


if __name__ == "__main__":
    asyncio.run(main())
