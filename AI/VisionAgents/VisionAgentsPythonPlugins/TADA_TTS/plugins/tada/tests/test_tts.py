import pytest
import pytest_asyncio

from vision_agents.plugins import tada
from vision_agents.core.tts.manual_test import manual_tts_to_wav
from vision_agents.core.tts.testing import TTSSession


class TestTadaTTS:
    @pytest_asyncio.fixture
    async def tts(self) -> tada.TTS:
        tts_instance = tada.TTS()
        await tts_instance.warmup()
        return tts_instance

    @pytest_asyncio.fixture
    async def tts_1b(self) -> tada.TTS:
        tts_instance = tada.TTS(model="HumeAI/tada-1b")
        await tts_instance.warmup()
        return tts_instance

    @pytest.mark.integration
    async def test_tada_tts_convert_text_to_audio_manual_test(self, tts: tada.TTS):
        await manual_tts_to_wav(tts, sample_rate=48000, channels=2)

    @pytest.mark.integration
    async def test_tada_tts_convert_text_to_audio(self, tts: tada.TTS):
        tts.set_output_format(sample_rate=16000, channels=1)
        session = TTSSession(tts)
        text = "Hello from TADA text to speech."

        await tts.send(text)
        await session.wait_for_result(timeout=60.0)

        assert not session.errors
        assert len(session.speeches) > 0

    @pytest.mark.integration
    async def test_tada_tts_1b_model(self, tts_1b: tada.TTS):
        tts_1b.set_output_format(sample_rate=16000, channels=1)
        session = TTSSession(tts_1b)
        text = "Testing the TADA one billion parameter model."

        await tts_1b.send(text)
        await session.wait_for_result(timeout=60.0)

        assert not session.errors
        assert len(session.speeches) > 0

    @pytest.mark.integration
    async def test_tada_tts_with_custom_voice(self):
        tts_instance = tada.TTS(
            voice="path/to/custom/voice.wav",
            voice_transcript="This is the transcript of my custom voice sample.",
        )
        await tts_instance.warmup()

        tts_instance.set_output_format(sample_rate=16000, channels=1)
        session = TTSSession(tts_instance)
        text = "Testing with a custom cloned voice."

        await tts_instance.send(text)
        await session.wait_for_result(timeout=60.0)

        assert not session.errors
        assert len(session.speeches) > 0

    @pytest.mark.integration
    async def test_tada_tts_multilingual(self):
        tts_instance = tada.TTS(
            model="HumeAI/tada-3b-ml",
            language="de",
        )
        await tts_instance.warmup()

        tts_instance.set_output_format(sample_rate=16000, channels=1)
        session = TTSSession(tts_instance)
        text = "Hallo, dies ist ein Test der mehrsprachigen Sprachsynthese."

        await tts_instance.send(text)
        await session.wait_for_result(timeout=60.0)

        assert not session.errors
        assert len(session.speeches) > 0
