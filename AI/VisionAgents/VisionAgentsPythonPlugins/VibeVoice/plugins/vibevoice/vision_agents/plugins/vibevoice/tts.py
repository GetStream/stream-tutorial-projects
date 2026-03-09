from __future__ import annotations

import asyncio
import logging
import os
from typing import AsyncIterator, Iterator, Optional

import numpy as np
import httpx
import websockets
from getstream.video.rtc.track_util import AudioFormat, PcmData
from vision_agents.core import tts

logger = logging.getLogger(__name__)

VIBEVOICE_DEFAULT_BASE_URL = "http://localhost:3000"
VIBEVOICE_SAMPLE_RATE = 24_000


class TTS(tts.TTS):
    """VibeVoice Text-to-Speech plugin for Vision Agents.

    Connects to a running VibeVoice server (Realtime-0.5B or 1.5B) via
    WebSocket and streams back high-fidelity PCM audio.  Supports
    expressive, long-form, multi-speaker conversational audio generation.

    The server must be started separately — see the VibeVoice README:
        python demo/vibevoice_realtime_demo.py \\
            --model_path microsoft/VibeVoice-Realtime-0.5B --port 3000
    """

    def __init__(
        self,
        base_url: Optional[str] = None,
        voice: Optional[str] = None,
        cfg_scale: float = 1.5,
        inference_steps: Optional[int] = None,
        sample_rate: int = VIBEVOICE_SAMPLE_RATE,
    ) -> None:
        """Create a new VibeVoice TTS instance.

        Args:
            base_url: HTTP(S) base URL of the VibeVoice server.  Falls back
                to the ``VIBEVOICE_BASE_URL`` env var, then ``http://localhost:3000``.
            voice: Speaker voice preset name (e.g. ``"en-Carter_man"``).
                When ``None`` the server default is used.
            cfg_scale: Classifier-Free Guidance scale (higher = more adherence
                to text).
            inference_steps: Diffusion inference steps.  ``None`` uses the
                server default (typically 5).
            sample_rate: Output sample rate — must match the VibeVoice model
                (24 kHz for Realtime-0.5B).
        """
        super().__init__()

        self.base_url = (
            base_url
            or os.getenv("VIBEVOICE_BASE_URL")
            or VIBEVOICE_DEFAULT_BASE_URL
        ).rstrip("/")

        self.voice = voice
        self.cfg_scale = cfg_scale
        self.inference_steps = inference_steps
        self.sample_rate = sample_rate

        self._ws_url = self.base_url.replace("http://", "ws://").replace(
            "https://", "wss://"
        )
        self._http_client: Optional[httpx.AsyncClient] = None
        self._stop_event = asyncio.Event()

    async def _ensure_http_client(self) -> httpx.AsyncClient:
        if self._http_client is None or self._http_client.is_closed:
            self._http_client = httpx.AsyncClient(timeout=10.0)
        return self._http_client

    async def get_available_voices(self) -> list[str]:
        """Query the VibeVoice server for its available voice presets."""
        client = await self._ensure_http_client()
        resp = await client.get(f"{self.base_url}/config")
        resp.raise_for_status()
        data = resp.json()
        return data.get("voices", [])

    def _build_ws_url(self, text: str) -> str:
        """Build the WebSocket URL with query parameters."""
        from urllib.parse import quote, urlencode

        params: dict[str, str] = {"text": text, "cfg": str(self.cfg_scale)}
        if self.inference_steps is not None:
            params["steps"] = str(self.inference_steps)
        if self.voice is not None:
            params["voice"] = self.voice
        return f"{self._ws_url}/stream?{urlencode(params, quote_via=quote)}"

    async def stream_audio(
        self, text: str, *_, **__
    ) -> PcmData | Iterator[PcmData] | AsyncIterator[PcmData]:
        """Stream synthesized speech from the VibeVoice server.

        Connects via WebSocket, sends the text as a query parameter, and
        yields ``PcmData`` chunks as binary PCM S16 frames arrive.
        """
        self._stop_event.clear()

        ws_url = self._build_ws_url(text)
        logger.info("VibeVoice TTS connecting to %s", ws_url)

        async def _audio_stream() -> AsyncIterator[PcmData]:
            try:
                async with websockets.connect(
                    ws_url,
                    max_size=2**22,
                    open_timeout=30,
                    close_timeout=5,
                ) as ws:
                    async for message in ws:
                        if self._stop_event.is_set():
                            break

                        if isinstance(message, bytes):
                            samples = np.frombuffer(message, dtype=np.int16)
                            yield PcmData(
                                sample_rate=self.sample_rate,
                                format=AudioFormat.S16,
                                samples=samples,
                                channels=1,
                            )
                        else:
                            logger.debug(
                                "VibeVoice server log: %s", message[:200]
                            )
            except websockets.exceptions.ConnectionClosed as exc:
                logger.warning("VibeVoice WebSocket closed: %s", exc)
            except Exception:
                logger.exception("Error streaming audio from VibeVoice")
                raise

        return _audio_stream()

    async def stop_audio(self) -> None:
        """Signal the streaming loop to stop."""
        self._stop_event.set()
        logger.info("VibeVoice TTS stop requested")

    async def close(self) -> None:
        """Tear down HTTP client."""
        self._stop_event.set()
        if self._http_client and not self._http_client.is_closed:
            await self._http_client.aclose()
            self._http_client = None
