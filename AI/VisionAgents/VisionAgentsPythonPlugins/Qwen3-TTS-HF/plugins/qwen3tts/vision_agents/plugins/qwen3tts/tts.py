import asyncio
import logging
from concurrent.futures import ThreadPoolExecutor
from typing import Any, AsyncIterator, Iterator, Literal, Optional

import numpy as np
import torch
from getstream.video.rtc.track_util import AudioFormat, PcmData
from vision_agents.core import tts

logger = logging.getLogger(__name__)

Speaker = Literal[
    "Vivian", "Serena", "Uncle_Fu", "Dylan", "Eric",
    "Ryan", "Aiden", "Ono_Anna", "Sohee",
]

SPEAKERS: list[str] = list(Speaker.__args__)  # type: ignore[attr-defined]

SUPPORTED_LANGUAGES = [
    "Chinese", "English", "Japanese", "Korean",
    "German", "French", "Russian", "Portuguese",
    "Spanish", "Italian", "Auto",
]

Mode = Literal["custom_voice", "voice_design", "voice_clone"]

MODEL_CUSTOM_VOICE_1_7B = "Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice"
MODEL_CUSTOM_VOICE_0_6B = "Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice"
MODEL_VOICE_DESIGN = "Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign"
MODEL_BASE_1_7B = "Qwen/Qwen3-TTS-12Hz-1.7B-Base"
MODEL_BASE_0_6B = "Qwen/Qwen3-TTS-12Hz-0.6B-Base"


class TTS(tts.TTS):
    """
    Qwen3-TTS integration for Vision Agents via HuggingFace Transformers.

    Qwen3-TTS is an open-source TTS series from Alibaba Cloud supporting
    10 languages, streaming generation, instruction-controlled prosody,
    and zero-shot voice cloning from 3-second audio clips.

    Three generation modes:
    - custom_voice: Use one of 9 built-in speakers with optional style instructions.
    - voice_design: Design a novel voice from a natural-language description.
    - voice_clone: Clone any voice from a short reference audio clip.
    """

    def __init__(
        self,
        model: str = MODEL_CUSTOM_VOICE_1_7B,
        mode: Mode = "custom_voice",
        speaker: Speaker = "Vivian",
        language: str = "Auto",
        instruct: Optional[str] = None,
        ref_audio: Optional[str] = None,
        ref_text: Optional[str] = None,
        device: str = "auto",
        dtype: str = "bfloat16",
        attn_implementation: Optional[str] = None,
    ) -> None:
        """
        Initialize the Qwen3-TTS service.

        Args:
            model: HuggingFace model ID. Defaults to the 1.7B CustomVoice model.
            mode: Generation mode — "custom_voice", "voice_design", or "voice_clone".
            speaker: Speaker name for custom_voice mode (e.g. "Vivian", "Ryan").
            language: Target language. "Auto" for auto-detection.
            instruct: Optional natural-language style instruction
                      (e.g. "Speak angrily", "Cheerful young female voice").
            ref_audio: Path, URL, or base64 string of reference audio for voice_clone.
            ref_text: Transcript of the reference audio for voice_clone.
            device: Torch device — "auto", "cuda", "mps", or "cpu".
            dtype: Torch dtype — "bfloat16", "float16", or "float32".
            attn_implementation: Attention backend — "flash_attention_2", "sdpa", or None.
        """
        super().__init__(provider_name="qwen3tts")

        self.model_id = model
        self.mode: Mode = mode
        self.speaker = speaker
        self.language = language
        self.instruct = instruct
        self.ref_audio = ref_audio
        self.ref_text = ref_text
        self.device = device
        self._dtype_str = dtype
        self.attn_implementation = attn_implementation

        self._model = None
        self._voice_clone_prompt = None
        self._executor = ThreadPoolExecutor(max_workers=2)

    def _resolve_device_and_dtype(self) -> tuple[str, torch.dtype]:
        """Pick the best device and a compatible dtype."""
        dtype_map = {
            "bfloat16": torch.bfloat16,
            "float16": torch.float16,
            "float32": torch.float32,
        }

        if self.device != "auto":
            device = self.device
        elif torch.cuda.is_available():
            device = "cuda:0"
        elif hasattr(torch.backends, "mps") and torch.backends.mps.is_available():
            device = "cpu"
            logger.info(
                "MPS detected but Qwen3-TTS uses device_map which works best "
                "with CPU on Apple Silicon. Using device='cpu'."
            )
        else:
            device = "cpu"

        if device == "cpu":
            dtype = torch.float32
            if self._dtype_str != "float32":
                logger.info("Overriding dtype to float32 for CPU device")
        else:
            dtype = dtype_map.get(self._dtype_str, torch.bfloat16)

        return device, dtype

    def _load_model(self):
        from qwen_tts import Qwen3TTSModel

        device, dtype = self._resolve_device_and_dtype()
        kwargs: dict[str, Any] = {
            "device_map": device,
            "dtype": dtype,
        }
        if self.attn_implementation:
            kwargs["attn_implementation"] = self.attn_implementation

        logger.info(
            "Loading Qwen3-TTS model %s on %s (%s)...",
            self.model_id, device, dtype,
        )
        try:
            model = Qwen3TTSModel.from_pretrained(self.model_id, **kwargs)
        except Exception:
            logger.exception("Failed to load Qwen3-TTS model")
            raise
        logger.info("Qwen3-TTS model loaded successfully")
        return model

    async def _ensure_loaded(self) -> None:
        if self._model is None:
            loop = asyncio.get_running_loop()
            self._model = await loop.run_in_executor(self._executor, self._load_model)

    def _generate_custom_voice(self, text: str, **kwargs) -> tuple:
        speaker = kwargs.get("speaker", self.speaker)
        language = kwargs.get("language", self.language)
        instruct = kwargs.get("instruct", self.instruct)

        gen_kwargs: dict[str, Any] = {
            "text": text,
            "language": language,
            "speaker": speaker,
        }
        if instruct:
            gen_kwargs["instruct"] = instruct

        return self._model.generate_custom_voice(**gen_kwargs)

    def _generate_voice_design(self, text: str, **kwargs) -> tuple:
        language = kwargs.get("language", self.language)
        instruct = kwargs.get("instruct", self.instruct)
        if not instruct:
            raise ValueError("instruct is required for voice_design mode")

        return self._model.generate_voice_design(
            text=text,
            language=language,
            instruct=instruct,
        )

    def _generate_voice_clone(self, text: str, **kwargs) -> tuple:
        language = kwargs.get("language", self.language)
        ref_audio = kwargs.get("ref_audio", self.ref_audio)
        ref_text = kwargs.get("ref_text", self.ref_text)

        if self._voice_clone_prompt is not None:
            return self._model.generate_voice_clone(
                text=text,
                language=language,
                voice_clone_prompt=self._voice_clone_prompt,
            )

        if not ref_audio:
            raise ValueError("ref_audio is required for voice_clone mode")

        gen_kwargs: dict[str, Any] = {
            "text": text,
            "language": language,
            "ref_audio": ref_audio,
        }
        if ref_text:
            gen_kwargs["ref_text"] = ref_text

        return self._model.generate_voice_clone(**gen_kwargs)

    async def prepare_voice_clone_prompt(
        self,
        ref_audio: Optional[str] = None,
        ref_text: Optional[str] = None,
    ) -> None:
        """
        Pre-compute and cache the voice-clone prompt for repeated use.

        Avoids recomputing prompt features on every call to stream_audio().

        Args:
            ref_audio: Path, URL, or base64 of the reference audio.
            ref_text: Transcript of the reference audio.
        """
        await self._ensure_loaded()
        audio = ref_audio or self.ref_audio
        text = ref_text or self.ref_text
        if not audio:
            raise ValueError("ref_audio is required")

        loop = asyncio.get_running_loop()
        self._voice_clone_prompt = await loop.run_in_executor(
            self._executor,
            lambda: self._model.create_voice_clone_prompt(
                ref_audio=audio,
                ref_text=text or "",
            ),
        )
        logger.info("Voice clone prompt cached")

    async def stream_audio(
        self, text: str, *_, **kwargs: Any
    ) -> PcmData | Iterator[PcmData] | AsyncIterator[PcmData]:
        """
        Convert text to speech using Qwen3-TTS.

        Args:
            text: The text to synthesize.
            **kwargs: Override speaker, language, instruct, ref_audio, ref_text per-call.

        Returns:
            PcmData containing the synthesized audio at the model's native sample rate.
        """
        await self._ensure_loaded()

        mode = kwargs.get("mode", self.mode)
        generators = {
            "custom_voice": self._generate_custom_voice,
            "voice_design": self._generate_voice_design,
            "voice_clone": self._generate_voice_clone,
        }
        generator = generators.get(mode)
        if not generator:
            raise ValueError(f"Unknown mode: {mode}")

        logger.info("Qwen3-TTS generating audio (mode=%s) for: %s", mode, text[:80])

        loop = asyncio.get_running_loop()
        try:
            wavs, sr = await loop.run_in_executor(
                self._executor, lambda: generator(text, **kwargs)
            )
        except Exception:
            logger.exception("Qwen3-TTS generation failed")
            raise

        audio_np = wavs[0] if isinstance(wavs[0], np.ndarray) else wavs[0].numpy()
        pcm16 = (np.clip(audio_np, -1.0, 1.0) * 32767.0).astype(np.int16)

        logger.info(
            "Qwen3-TTS generated %d samples at %d Hz (%.1fs)",
            len(pcm16), sr, len(pcm16) / sr,
        )

        return PcmData.from_numpy(
            pcm16, sample_rate=sr, channels=1, format=AudioFormat.S16,
        )

    async def stop_audio(self) -> None:
        """Stop current audio synthesis (no-op for batch generation)."""
        logger.info("Qwen3-TTS stop requested")

    async def close(self) -> None:
        """Release model and thread pool resources."""
        await super().close()
        self._model = None
        self._voice_clone_prompt = None
        self._executor.shutdown(wait=False)
