import asyncio
import logging
import os
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Any, AsyncIterator, Iterator, Literal, Optional

import numpy as np
import torch

from getstream.video.rtc.track_util import AudioFormat, PcmData
from vision_agents.core import tts
from vision_agents.core.warmup import Warmable

from neutts import NeuTTS

logger = logging.getLogger(__name__)

Backbone = Literal[
    "neuphonic/neutts-air",
    "neuphonic/neutts-air-q4-gguf",
    "neuphonic/neutts-air-q8-gguf",
    "neuphonic/neutts-nano",
    "neuphonic/neutts-nano-q4-gguf",
    "neuphonic/neutts-nano-q8-gguf",
    "neuphonic/neutts-nano-french",
    "neuphonic/neutts-nano-french-q4-gguf",
    "neuphonic/neutts-nano-french-q8-gguf",
    "neuphonic/neutts-nano-german",
    "neuphonic/neutts-nano-german-q4-gguf",
    "neuphonic/neutts-nano-german-q8-gguf",
    "neuphonic/neutts-nano-spanish",
    "neuphonic/neutts-nano-spanish-q4-gguf",
    "neuphonic/neutts-nano-spanish-q8-gguf",
]

_GITHUB_RAW = "https://raw.githubusercontent.com/neuphonic/neutts/main/samples"

_DEFAULT_SAMPLES = {
    "en": {"wav": "jo.wav", "txt": "jo.txt"},
    "de": {"wav": "greta.wav", "txt": "greta.txt"},
    "fr": {"wav": "juliette.wav", "txt": "juliette.txt"},
    "es": {"wav": "mateo.wav", "txt": "mateo.txt"},
}

_BACKBONE_LANG_PREFIX = {
    "neuphonic/neutts-air": "en",
    "neuphonic/neutts-air-q4-gguf": "en",
    "neuphonic/neutts-air-q8-gguf": "en",
    "neuphonic/neutts-nano": "en",
    "neuphonic/neutts-nano-q4-gguf": "en",
    "neuphonic/neutts-nano-q8-gguf": "en",
    "neuphonic/neutts-nano-french": "fr",
    "neuphonic/neutts-nano-french-q4-gguf": "fr",
    "neuphonic/neutts-nano-french-q8-gguf": "fr",
    "neuphonic/neutts-nano-german": "de",
    "neuphonic/neutts-nano-german-q4-gguf": "de",
    "neuphonic/neutts-nano-german-q8-gguf": "de",
    "neuphonic/neutts-nano-spanish": "es",
    "neuphonic/neutts-nano-spanish-q4-gguf": "es",
    "neuphonic/neutts-nano-spanish-q8-gguf": "es",
}


def _cache_dir() -> Path:
    """Return the local cache directory for default reference samples."""
    base = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
    d = base / "neutts-vision-agents" / "samples"
    d.mkdir(parents=True, exist_ok=True)
    return d


def _download_default_samples(lang_prefix: str) -> tuple[str, str]:
    """Download default reference .wav and .txt for the given language prefix."""
    entry = _DEFAULT_SAMPLES.get(lang_prefix, _DEFAULT_SAMPLES["en"])
    cache = _cache_dir()
    wav_path = cache / entry["wav"]
    txt_path = cache / entry["txt"]

    for fname, local_path in [(entry["wav"], wav_path), (entry["txt"], txt_path)]:
        if not local_path.exists():
            url = f"{_GITHUB_RAW}/{fname}"
            logger.info("Downloading default reference: %s", url)
            urllib.request.urlretrieve(url, str(local_path))

    return str(wav_path), str(txt_path)


def _read_text_file_or_string(value: str) -> str:
    """If value is a path to an existing file, read it; otherwise return as-is."""
    if value and os.path.exists(value):
        with open(value, "r", encoding="utf-8") as f:
            return f.read().strip()
    return value


class TTS(tts.TTS, Warmable[tuple[NeuTTS, Any, str]]):
    """
    Neu TTS Text-to-Speech implementation.

    An on-device TTS model by Neuphonic with instant voice cloning,
    multilingual support, and real-time performance on CPU.
    No API key required — runs entirely locally.

    When no reference audio is provided, a default voice sample is
    automatically downloaded from the NeuTTS GitHub repository and cached
    in ~/.cache/neutts-vision-agents/.
    """

    def __init__(
        self,
        backbone: Backbone | str = "neuphonic/neutts-nano",
        backbone_device: str = "cpu",
        codec_repo: str = "neuphonic/neucodec",
        codec_device: str = "cpu",
        language: Optional[str] = None,
        ref_audio_path: Optional[str] = None,
        ref_text: Optional[str] = None,
        client: Optional[NeuTTS] = None,
    ) -> None:
        """
        Initialize Neu TTS.

        Args:
            backbone: HuggingFace backbone model repo. Use GGUF variants for
                streaming support and lower latency on CPU.
            backbone_device: Device for the backbone model ("cpu" or "gpu").
            codec_repo: HuggingFace codec repo. Use "neuphonic/neucodec-onnx-decoder"
                for lower latency with GGUF backbones.
            codec_device: Device for the codec model ("cpu" or "gpu").
            language: Language code (e.g. "en-us", "de", "fr-fr", "es").
                Auto-detected from backbone if using a Neuphonic model.
            ref_audio_path: Path to a reference .wav file for voice cloning.
                If not provided, a default sample is downloaded automatically.
            ref_text: Transcript of the reference audio, or path to a .txt file
                containing the transcript.
            client: Optional pre-initialized NeuTTS instance.
        """
        super().__init__(provider_name="neutts")

        self.backbone = backbone
        self.backbone_device = backbone_device
        self.codec_repo = codec_repo
        self.codec_device = codec_device
        self.language = language
        self.ref_audio_path = ref_audio_path
        self.ref_text = ref_text

        self._model: Optional[NeuTTS] = client
        self._ref_codes: Optional[torch.Tensor] = None
        self._ref_text_content: Optional[str] = None
        self._executor = ThreadPoolExecutor(max_workers=4)

    def _ensure_reference(self) -> None:
        """Download default reference samples when none are provided and resolve text."""
        if not self.ref_audio_path or not self.ref_text:
            lang = _BACKBONE_LANG_PREFIX.get(self.backbone, "en")
            wav_path, txt_path = _download_default_samples(lang)
            if not self.ref_audio_path:
                self.ref_audio_path = wav_path
            if not self.ref_text:
                self.ref_text = txt_path

        self._ref_text_content = _read_text_file_or_string(self.ref_text)
        logger.info(
            "Reference text loaded (%d chars)", len(self._ref_text_content or "")
        )

    async def on_warmup(self) -> tuple[NeuTTS, Any, str]:
        if (
            self._model is not None
            and self._ref_codes is not None
            and self._ref_text_content
        ):
            return (self._model, self._ref_codes, self._ref_text_content)

        loop = asyncio.get_running_loop()

        # Download default reference if needed and resolve text content
        await loop.run_in_executor(self._executor, self._ensure_reference)

        if self._model is not None:
            model = self._model
        else:
            logger.info("Loading Neu TTS model (backbone=%s)...", self.backbone)

            def _load_model():
                kwargs: dict[str, Any] = {
                    "backbone_repo": self.backbone,
                    "backbone_device": self.backbone_device,
                    "codec_repo": self.codec_repo,
                    "codec_device": self.codec_device,
                }
                if self.language:
                    kwargs["language"] = self.language
                return NeuTTS(**kwargs)

            model = await loop.run_in_executor(self._executor, _load_model)
            logger.info("Neu TTS model loaded")

        ref_audio_path = self.ref_audio_path
        pt_path = ref_audio_path.replace(".wav", ".pt") if ref_audio_path else None

        if pt_path and os.path.exists(pt_path):
            logger.info("Loading pre-encoded reference from %s", pt_path)
            ref_codes = await loop.run_in_executor(
                self._executor, lambda: torch.load(pt_path)
            )
        elif ref_audio_path:
            logger.info("Encoding reference audio: %s", ref_audio_path)
            ref_codes = await loop.run_in_executor(
                self._executor,
                lambda: model.encode_reference(ref_audio_path),
            )
        else:
            raise ValueError(
                "ref_audio_path is required. Provide a .wav file for voice cloning."
            )

        ref_text_content = self._ref_text_content or ""
        return (model, ref_codes, ref_text_content)

    def on_warmed_up(self, resource: tuple[NeuTTS, Any, str]) -> None:
        self._model, self._ref_codes, self._ref_text_content = resource

    async def _ensure_loaded(self) -> None:
        """Ensure model, reference codes, and reference text are all loaded."""
        if (
            self._model is None
            or self._ref_codes is None
            or not self._ref_text_content
        ):
            resource = await self.on_warmup()
            self.on_warmed_up(resource)

    async def stream_audio(
        self, text: str, *_, **__
    ) -> PcmData | Iterator[PcmData] | AsyncIterator[PcmData]:
        """
        Convert text to speech using Neu TTS.

        Args:
            text: The text to convert to speech.

        Returns:
            PcmData containing the synthesized audio at 24kHz.
        """
        await self._ensure_loaded()
        assert self._model is not None
        assert self._ref_codes is not None
        assert self._ref_text_content, "Reference text must not be empty"

        model = self._model
        ref_codes = self._ref_codes
        ref_text = self._ref_text_content

        def _generate():
            wav = model.infer(text, ref_codes, ref_text)
            pcm16 = (np.clip(wav, -1.0, 1.0) * 32767.0).astype(np.int16)
            return pcm16

        loop = asyncio.get_running_loop()
        samples = await loop.run_in_executor(self._executor, _generate)

        return PcmData.from_numpy(
            samples,
            sample_rate=self._model.sample_rate,
            channels=1,
            format=AudioFormat.S16,
        )

    async def stop_audio(self) -> None:
        """Stop audio playback (no-op for Neu TTS batch inference)."""
        logger.info("Neu TTS stop requested (no-op)")

    async def close(self) -> None:
        """Close the TTS and cleanup resources."""
        await super().close()
        self._executor.shutdown(wait=False)
