import pytest
import pytest_asyncio

from vision_agents.plugins import neutts
from vision_agents.core.tts.manual_test import manual_tts_to_wav
from vision_agents.core.tts.testing import TTSSession


class TestNeuTTS:
    @pytest_asyncio.fixture
    async def tts(self) -> neutts.TTS:
        tts_instance = neutts.TTS()
        await tts_instance.warmup()
        return tts_instance

    @pytest.mark.integration
    async def test_neutts_convert_text_to_audio_manual_test(self, tts: neutts.TTS):
        await manual_tts_to_wav(tts, sample_rate=48000, channels=2)

    @pytest.mark.integration
    async def test_neutts_convert_text_to_audio(self, tts: neutts.TTS):
        tts.set_output_format(sample_rate=24000, channels=1)
        session = TTSSession(tts)
        text = "Hello from Neu TTS by Neuphonic."

        await tts.send(text)
        await session.wait_for_result(timeout=60.0)

        assert not session.errors
        assert len(session.speeches) > 0

    @pytest.mark.integration
    async def test_neutts_with_air_backbone(self):
        tts_instance = neutts.TTS(backbone="neuphonic/neutts-air")
        await tts_instance.warmup()

        tts_instance.set_output_format(sample_rate=24000, channels=1)
        session = TTSSession(tts_instance)
        text = "Testing with the Neu TTS Air model."

        await tts_instance.send(text)
        await session.wait_for_result(timeout=60.0)

        assert not session.errors
        assert len(session.speeches) > 0

    @pytest.mark.integration
    async def test_neutts_with_gguf_backbone(self):
        tts_instance = neutts.TTS(
            backbone="neuphonic/neutts-nano-q8-gguf",
            codec_repo="neuphonic/neucodec-onnx-decoder",
        )
        await tts_instance.warmup()

        tts_instance.set_output_format(sample_rate=24000, channels=1)
        session = TTSSession(tts_instance)
        text = "Testing with a quantized GGUF model."

        await tts_instance.send(text)
        await session.wait_for_result(timeout=60.0)

        assert not session.errors
        assert len(session.speeches) > 0
