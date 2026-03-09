import pytest
import pytest_asyncio

from vision_agents.plugins import kittentts
from vision_agents.core.tts.manual_test import manual_tts_to_wav
from vision_agents.core.tts.testing import TTSSession


class TestKittenTTS:
    @pytest_asyncio.fixture
    async def tts(self) -> kittentts.TTS:
        tts_instance = kittentts.TTS()
        await tts_instance.warmup()
        return tts_instance

    @pytest.mark.integration
    async def test_kittentts_convert_text_to_audio_manual_test(
        self, tts: kittentts.TTS
    ):
        await manual_tts_to_wav(tts, sample_rate=48000, channels=2)

    @pytest.mark.integration
    async def test_kittentts_convert_text_to_audio(self, tts: kittentts.TTS):
        tts.set_output_format(sample_rate=16000, channels=1)
        session = TTSSession(tts)
        text = "Hello from KittenTTS."

        await tts.send(text)
        await session.wait_for_result(timeout=30.0)

        assert not session.errors
        assert len(session.speeches) > 0

    @pytest.mark.integration
    async def test_kittentts_with_different_voice(self):
        tts_instance = kittentts.TTS(voice="Jasper")
        await tts_instance.warmup()

        tts_instance.set_output_format(sample_rate=16000, channels=1)
        session = TTSSession(tts_instance)
        text = "Testing with the Jasper voice."

        await tts_instance.send(text)
        await session.wait_for_result(timeout=30.0)

        assert not session.errors
        assert len(session.speeches) > 0

    @pytest.mark.integration
    async def test_kittentts_with_nano_model(self):
        tts_instance = kittentts.TTS(
            model="KittenML/kitten-tts-nano-0.8",
            voice="Luna",
        )
        await tts_instance.warmup()

        tts_instance.set_output_format(sample_rate=16000, channels=1)
        session = TTSSession(tts_instance)
        text = "Testing with the nano model."

        await tts_instance.send(text)
        await session.wait_for_result(timeout=30.0)

        assert not session.errors
        assert len(session.speeches) > 0

    @pytest.mark.integration
    async def test_kittentts_with_speed_adjustment(self):
        tts_instance = kittentts.TTS(speed=1.5)
        await tts_instance.warmup()

        tts_instance.set_output_format(sample_rate=16000, channels=1)
        session = TTSSession(tts_instance)
        text = "Testing with faster speech speed."

        await tts_instance.send(text)
        await session.wait_for_result(timeout=30.0)

        assert not session.errors
        assert len(session.speeches) > 0
