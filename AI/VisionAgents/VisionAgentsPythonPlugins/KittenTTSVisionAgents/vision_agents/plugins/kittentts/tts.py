import asyncio
import logging
from concurrent.futures import ThreadPoolExecutor
from typing import AsyncIterator, Iterator, Literal

import numpy as np

from getstream.video.rtc.track_util import AudioFormat, PcmData
from vision_agents.core import tts
from vision_agents.core.warmup import Warmable

from kittentts import KittenTTS

logger = logging.getLogger(__name__)

SAMPLE_RATE = 24000

Voice = Literal[
    "Bella",
    "Jasper",
    "Luna",
    "Bruno",
    "Rosie",
    "Hugo",
    "Kiki",
    "Leo",
]

Model = Literal[
    "KittenML/kitten-tts-mini-0.8",
    "KittenML/kitten-tts-micro-0.8",
    "KittenML/kitten-tts-nano-0.8",
    "KittenML/kitten-tts-nano-0.8-int8",
]


class TTS(tts.TTS, Warmable[KittenTTS]):
    """
    KittenTTS Text-to-Speech implementation for Vision Agents.

    An ultra-lightweight CPU-based TTS model from KittenML with high-quality
    voice synthesis. The model is under 25MB (int8) and runs without a GPU.
    """

    def __init__(
        self,
        model: Model | str = "KittenML/kitten-tts-mini-0.8",
        voice: Voice | str = "Bella",
        speed: float = 1.0,
        client: KittenTTS | None = None,
    ) -> None:
        """
        Initialize KittenTTS.

        Args:
            model: HuggingFace model ID or name. Defaults to kitten-tts-mini-0.8.
            voice: Voice name to use for synthesis.
            speed: Speech speed multiplier (1.0 = normal).
            client: Optional pre-initialized KittenTTS instance.
        """
        super().__init__(provider_name="kittentts")

        self.model_name = model
        self.voice = voice
        self.speed = speed
        self._model: KittenTTS | None = client
        self._executor = ThreadPoolExecutor(max_workers=4)

    async def on_warmup(self) -> KittenTTS:
        if self._model is not None:
            return self._model

        loop = asyncio.get_running_loop()

        logger.info("Loading KittenTTS model: %s ...", self.model_name)
        model = await loop.run_in_executor(
            self._executor,
            lambda: KittenTTS(self.model_name),
        )
        logger.info("KittenTTS model loaded successfully")
        return model

    def on_warmed_up(self, resource: KittenTTS) -> None:
        self._model = resource

    async def _ensure_loaded(self) -> None:
        """Ensure model is loaded."""
        if self._model is None:
            resource = await self.on_warmup()
            self.on_warmed_up(resource)

    async def stream_audio(
        self, text: str, *_, **__
    ) -> PcmData | Iterator[PcmData] | AsyncIterator[PcmData]:
        """
        Convert text to speech using KittenTTS.

        Args:
            text: The text to convert to speech.

        Returns:
            PcmData containing the synthesized audio at 24kHz.
        """
        await self._ensure_loaded()
        assert self._model is not None

        model = self._model
        voice = self.voice
        speed = self.speed

        def _generate():
            audio_np = model.generate(text, voice=voice, speed=speed)
            audio_np = np.asarray(audio_np, dtype=np.float32)
            pcm16 = (np.clip(audio_np, -1.0, 1.0) * 32767.0).astype(np.int16)
            return pcm16

        loop = asyncio.get_running_loop()
        samples = await loop.run_in_executor(self._executor, _generate)

        return PcmData.from_numpy(
            samples, sample_rate=SAMPLE_RATE, channels=1, format=AudioFormat.S16
        )

    async def stop_audio(self) -> None:
        """Stop audio playback (no-op for KittenTTS as it generates synchronously)."""
        logger.info("KittenTTS stop requested (no-op)")

    async def close(self) -> None:
        """Close the TTS and cleanup resources."""
        await super().close()
        self._executor.shutdown(wait=False)
