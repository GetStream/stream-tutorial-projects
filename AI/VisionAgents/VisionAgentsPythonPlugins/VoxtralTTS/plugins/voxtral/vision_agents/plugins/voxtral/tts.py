import asyncio
import base64
import logging
import os
import struct
from typing import Any, AsyncIterator, Iterator, Optional

import numpy as np
from getstream.video.rtc.track_util import AudioFormat, PcmData
from vision_agents.core import tts

logger = logging.getLogger(__name__)

DEFAULT_MODEL = "voxtral-mini-tts-2603"

VOXTRAL_PCM_SAMPLE_RATE = 24000


class TTS(tts.TTS):
    """
    Voxtral TTS (Mistral) Text-to-Speech implementation.

    Voxtral TTS is Mistral's text-to-speech model featuring zero-shot voice
    cloning, multilingual support (9 languages), and low-latency streaming.
    It captures emotion, speaking style, and accent from short audio prompts.

    Supports two voice modes:
    - voice_id: Use a previously saved/created voice by its ID.
    - ref_audio: Pass base64-encoded audio directly for on-the-fly voice cloning.
    """

    def __init__(
        self,
        api_key: Optional[str] = None,
        model: str = DEFAULT_MODEL,
        voice_id: Optional[str] = None,
        ref_audio: Optional[str] = None,
        response_format: str = "pcm",
    ):
        """
        Initialize the Voxtral TTS service.

        Args:
            api_key: Mistral API key. Falls back to MISTRAL_API_KEY env var.
            model: Model identifier. Defaults to "voxtral-mini-tts-2603".
            voice_id: Saved voice ID for consistent voice reuse.
            ref_audio: Base64-encoded audio for zero-shot voice cloning.
                       Use 3-25 seconds of clean, single-speaker audio.
            response_format: Audio output format. "pcm" gives lowest latency
                             (~0.7s TTFA). Also supports "mp3", "wav", "opus", "flac".
        """
        super().__init__(provider_name="voxtral")

        if not api_key:
            api_key = os.environ.get("MISTRAL_API_KEY")
        if not api_key:
            raise ValueError(
                "api_key is required. Pass it directly or set MISTRAL_API_KEY."
            )

        from mistralai.client import Mistral

        self.client = Mistral(api_key=api_key)
        self.model = model
        self.voice_id = voice_id
        self.ref_audio = ref_audio
        self.response_format = response_format

    async def stream_audio(
        self, text: str, *_, **kwargs: Any
    ) -> PcmData | Iterator[PcmData] | AsyncIterator[PcmData]:
        """
        Convert text to speech using Voxtral TTS.

        Collects streamed audio chunks from the Mistral API, converts
        from float32 PCM to int16, and returns a single PcmData object.

        Args:
            text: The text to synthesize.
            **kwargs: Override voice_id or ref_audio per-call.

        Returns:
            PcmData containing the synthesized audio.
        """
        voice_id = kwargs.get("voice_id", self.voice_id)
        ref_audio = kwargs.get("ref_audio", self.ref_audio)

        speech_kwargs: dict[str, Any] = {
            "model": self.model,
            "input": text,
            "response_format": self.response_format,
            "stream": True,
        }

        if voice_id:
            speech_kwargs["voice_id"] = voice_id
        elif ref_audio:
            speech_kwargs["ref_audio"] = ref_audio

        loop = asyncio.get_running_loop()

        def _run_stream():
            chunks: list[bytes] = []
            with self.client.audio.speech.complete(**speech_kwargs) as stream:
                for event in stream:
                    if event.event == "speech.audio.delta":
                        chunks.append(base64.b64decode(event.data.audio_data))
                    elif event.event == "speech.audio.done":
                        logger.debug(
                            "Voxtral TTS stream complete",
                            extra={"usage": str(event.data.usage)},
                        )
            return b"".join(chunks)

        raw_bytes = await loop.run_in_executor(None, _run_stream)

        # Voxtral PCM format is raw float32 little-endian samples at 24kHz
        num_samples = len(raw_bytes) // 4
        float_samples = struct.unpack(f"<{num_samples}f", raw_bytes)
        audio_np = np.array(float_samples, dtype=np.float32)
        pcm16 = (np.clip(audio_np, -1.0, 1.0) * 32767.0).astype(np.int16)

        return PcmData.from_numpy(
            pcm16,
            sample_rate=VOXTRAL_PCM_SAMPLE_RATE,
            channels=1,
            format=AudioFormat.S16,
        )

    async def stop_audio(self) -> None:
        """Stop current audio synthesis."""
        logger.info("Voxtral TTS stop requested")

    async def close(self) -> None:
        """Clean up resources."""
        await super().close()
