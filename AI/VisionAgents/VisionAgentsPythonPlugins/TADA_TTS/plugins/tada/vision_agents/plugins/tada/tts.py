import asyncio
import logging
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import TYPE_CHECKING, Any, AsyncIterator, Iterator, Literal, Optional

import numpy as np
import torch

from getstream.video.rtc.track_util import AudioFormat, PcmData
from vision_agents.core import tts

if TYPE_CHECKING:
    from tada.modules.encoder import Encoder
    from tada.modules.tada import InferenceOptions, TadaForCausalLM

logger = logging.getLogger(__name__)

TADA_SAMPLE_RATE = 24000

Model = Literal["HumeAI/tada-1b", "HumeAI/tada-3b-ml"]

SUPPORTED_LANGUAGES = Literal[
    "en", "ar", "ch", "de", "es", "fr", "it", "ja", "pl", "pt"
]


def _load_inference_options() -> type:
    from tada.modules.tada import InferenceOptions
    return InferenceOptions


class TTS(tts.TTS):
    """
    TADA Text-to-Speech implementation for Vision Agents.

    TADA (Text-Acoustic Dual Alignment) by Hume AI is a generative speech
    language model that synchronizes text and speech into a single stream
    via 1:1 alignment. It achieves high-fidelity synthesis with low latency,
    zero hallucinations, and supports voice cloning via reference audio.

    Requires a CUDA-capable GPU for optimal performance.
    """

    def __init__(
        self,
        model: Model = "HumeAI/tada-3b-ml",
        voice: Optional[str] = None,
        voice_transcript: Optional[str] = None,
        language: Optional[str] = None,
        device: Optional[str] = None,
        inference_options: Optional["InferenceOptions"] = None,
    ) -> None:
        """
        Initialize TADA TTS.

        Args:
            model: HuggingFace model ID. Options: "HumeAI/tada-1b" (English),
                   "HumeAI/tada-3b-ml" (multilingual). Defaults to "HumeAI/tada-3b-ml".
            voice: Path to a reference WAV file for voice cloning. If not provided,
                   uses the bundled LJSpeech sample voice.
            voice_transcript: Transcript of the reference audio. Required for
                              non-English reference audio to ensure proper alignment.
                              For English audio, the built-in ASR handles this automatically.
            language: Language code for the encoder aligner. Options: "en" (default),
                      "ar", "ch", "de", "es", "fr", "it", "ja", "pl", "pt".
                      Only needed for non-English synthesis with tada-3b-ml.
            device: PyTorch device string (e.g., "cuda", "cuda:0", "cpu").
                    Defaults to "cuda" if available, otherwise "cpu".
            inference_options: Advanced generation options (temperature, CFG scales, etc.).
                               Pass an instance of ``tada.modules.tada.InferenceOptions``.
        """
        super().__init__(provider_name="tada")

        self._model_id = model
        self._voice_path = voice
        self._voice_transcript = voice_transcript
        self._language = language
        self._device = device or ("cuda" if torch.cuda.is_available() else "cpu")
        self._inference_options = inference_options

        self._model: Optional["TadaForCausalLM"] = None
        self._encoder: Optional["Encoder"] = None
        self._prompt: Any = None
        self._executor = ThreadPoolExecutor(max_workers=2)
        self._generating = False
        self._loaded = False
        self._loading_lock = asyncio.Lock()

    def _get_inference_options(self) -> "InferenceOptions":
        if self._inference_options is not None:
            return self._inference_options
        InferenceOptions = _load_inference_options()
        return InferenceOptions()

    async def warmup(self) -> None:
        """Pre-load encoder, model, and voice prompt before the call starts."""
        await self._load_models()

    async def _load_models(self) -> None:
        """Load encoder, model, and voice prompt (thread-safe, runs once)."""
        if self._loaded:
            return

        async with self._loading_lock:
            if self._loaded:
                return

            loop = asyncio.get_running_loop()

            logger.info("Loading TADA encoder (HumeAI/tada-codec)...")

            def _load_encoder():
                from tada.modules.encoder import Encoder

                kwargs: dict[str, Any] = {
                    "pretrained_model_name_or_path": "HumeAI/tada-codec",
                    "subfolder": "encoder",
                }
                if self._language and self._language != "en":
                    kwargs["language"] = self._language
                return Encoder.from_pretrained(**kwargs).to(self._device)

            self._encoder = await loop.run_in_executor(self._executor, _load_encoder)
            logger.info("TADA encoder loaded")

            logger.info(f"Loading TADA model ({self._model_id})...")

            def _load_model():
                from tada.modules.tada import TadaForCausalLM

                return TadaForCausalLM.from_pretrained(self._model_id).to(self._device)

            self._model = await loop.run_in_executor(self._executor, _load_model)
            logger.info("TADA model loaded")

            logger.info("Preparing voice prompt...")
            self._prompt = await loop.run_in_executor(
                self._executor,
                lambda: self._build_prompt(self._encoder, self._model),
            )
            logger.info("TADA voice prompt prepared — ready to synthesize")

            self._loaded = True

    def _build_prompt(self, encoder: "Encoder", model: "TadaForCausalLM") -> Any:
        """Build the encoder prompt from reference audio."""
        import torchaudio

        if self._voice_path:
            voice_path = self._voice_path
        else:
            import tada.samples
            samples_dir = Path(tada.samples.__path__[0])
            voice_path = str(samples_dir / "ljspeech.wav")

        audio, sample_rate = torchaudio.load(voice_path)
        audio = audio.to(self._device)

        prompt_kwargs: dict[str, Any] = {
            "sample_rate": sample_rate,
        }

        if self._voice_transcript:
            prompt_kwargs["text"] = [self._voice_transcript]
        elif self._voice_path is None:
            prompt_kwargs["text"] = [
                "The examination and testimony of the experts, enabled the "
                "commission to conclude that five shots may have been fired."
            ]

        return encoder(audio, **prompt_kwargs)

    async def stream_audio(
        self, text: str, *_, **__
    ) -> PcmData | Iterator[PcmData] | AsyncIterator[PcmData]:
        """
        Convert text to speech using TADA.

        Args:
            text: The text to convert to speech.

        Returns:
            PcmData containing the synthesized audio at 24kHz mono.
        """
        await self._load_models()
        assert self._model is not None
        assert self._prompt is not None

        model = self._model
        prompt = self._prompt
        inference_options = self._get_inference_options()
        self._generating = True

        def _generate():
            with torch.no_grad():
                output = model.generate(
                    prompt=prompt,
                    text=text,
                    inference_options=inference_options,
                )
            wav = output.audio[0]
            if wav is None:
                raise RuntimeError("TADA generation failed: no audio produced")
            audio_np = wav.cpu().float().numpy()
            pcm16 = (np.clip(audio_np, -1.0, 1.0) * 32767.0).astype(np.int16)
            return pcm16

        loop = asyncio.get_running_loop()
        try:
            samples = await loop.run_in_executor(self._executor, _generate)
        finally:
            self._generating = False

        return PcmData.from_numpy(
            samples, sample_rate=TADA_SAMPLE_RATE, channels=1, format=AudioFormat.S16
        )

    async def stop_audio(self) -> None:
        """Stop current synthesis."""
        self._generating = False
        logger.info("TADA TTS stop requested")

    async def close(self) -> None:
        """Close the TTS and release GPU resources."""
        await super().close()
        self._generating = False

        if self._model is not None:
            del self._model
            self._model = None
        if self._encoder is not None:
            del self._encoder
            self._encoder = None
        if self._prompt is not None:
            del self._prompt
            self._prompt = None

        if torch.cuda.is_available():
            torch.cuda.empty_cache()

        self._executor.shutdown(wait=False)
        self._loaded = False
