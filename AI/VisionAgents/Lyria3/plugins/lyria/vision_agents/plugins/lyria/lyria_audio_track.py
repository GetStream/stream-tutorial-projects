import asyncio
import logging
import struct
from typing import Optional

import av
import numpy as np
from aiortc import AudioStreamTrack

logger = logging.getLogger(__name__)

LYRIA_SAMPLE_RATE = 48000
LYRIA_CHANNELS = 2
LYRIA_SAMPLE_WIDTH = 2  # 16-bit PCM


class LyriaAudioTrack(AudioStreamTrack):
    """Audio track that streams Lyria-generated music to the call.

    Receives raw 16-bit PCM audio chunks from Lyria RealTime (48kHz stereo)
    and provides them through the AudioStreamTrack interface for publishing.
    """

    kind = "audio"

    def __init__(
        self,
        sample_rate: int = LYRIA_SAMPLE_RATE,
        channels: int = LYRIA_CHANNELS,
    ):
        super().__init__()
        self.sample_rate = sample_rate
        self.channels = channels
        self._queue: asyncio.Queue[bytes] = asyncio.Queue(maxsize=50)
        self._stopped = False
        self._pts = 0

        logger.debug(
            f"LyriaAudioTrack initialized ({sample_rate}Hz, {channels}ch)"
        )

    async def add_audio_chunk(self, raw_pcm: bytes) -> None:
        """Add a raw PCM audio chunk from Lyria to the playback queue."""
        if self._stopped:
            return
        try:
            self._queue.put_nowait(raw_pcm)
        except asyncio.QueueFull:
            try:
                self._queue.get_nowait()
            except asyncio.QueueEmpty:
                pass
            self._queue.put_nowait(raw_pcm)

    async def recv(self) -> av.AudioFrame:
        if self._stopped:
            raise ValueError("Track stopped")

        try:
            raw_pcm = await asyncio.wait_for(self._queue.get(), timeout=0.1)
        except asyncio.TimeoutError:
            num_samples = self.sample_rate // 50  # 20ms of silence
            raw_pcm = b"\x00" * (num_samples * self.channels * LYRIA_SAMPLE_WIDTH)

        num_samples_per_channel = len(raw_pcm) // (self.channels * LYRIA_SAMPLE_WIDTH)
        samples = np.frombuffer(raw_pcm, dtype=np.int16)
        samples = samples.reshape(-1, self.channels).T  # shape: (channels, samples)

        frame = av.AudioFrame.from_ndarray(
            samples, format="s16", layout="stereo" if self.channels == 2 else "mono"
        )
        frame.sample_rate = self.sample_rate
        frame.pts = self._pts
        frame.time_base = f"1/{self.sample_rate}"
        self._pts += num_samples_per_channel

        return frame

    @property
    def is_stopped(self) -> bool:
        return self._stopped

    def stop(self) -> None:
        self._stopped = True
        super().stop()
