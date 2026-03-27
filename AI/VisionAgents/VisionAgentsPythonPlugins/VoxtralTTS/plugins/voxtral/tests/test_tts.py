import pytest
import pytest_asyncio
from dotenv import load_dotenv

from vision_agents.plugins import voxtral
from vision_agents.core.tts.manual_test import manual_tts_to_wav
from vision_agents.core.tts.testing import TTSSession

load_dotenv()


class TestVoxtralTTS:
    @pytest_asyncio.fixture
    async def tts(self) -> voxtral.TTS:
        return voxtral.TTS(model="voxtral-mini-tts-2603")

    @pytest.mark.integration
    async def test_voxtral_tts_convert_text_to_audio_manual_test(
        self, tts: voxtral.TTS
    ):
        await manual_tts_to_wav(tts, sample_rate=48000, channels=2)

    @pytest.mark.integration
    async def test_voxtral_tts_convert_text_to_audio(self, tts: voxtral.TTS):
        tts.set_output_format(sample_rate=16000, channels=1)
        session = TTSSession(tts)
        text = "Hello from Voxtral TTS! This is Mistral's text-to-speech model."

        await tts.send(text)
        await session.wait_for_result(timeout=15.0)

        assert not session.errors
        assert len(session.speeches) > 0

    @pytest.mark.integration
    async def test_voxtral_tts_multilingual(self, tts: voxtral.TTS):
        tts.set_output_format(sample_rate=16000, channels=1)
        session = TTSSession(tts)
        text = "Bonjour! Je suis un assistant vocal propulsé par Voxtral."

        await tts.send(text)
        await session.wait_for_result(timeout=15.0)

        assert not session.errors
        assert len(session.speeches) > 0

    @pytest.mark.integration
    async def test_voxtral_tts_with_voice_id(self):
        tts_instance = voxtral.TTS(
            model="voxtral-mini-tts-2603",
            voice_id="your-voice-id",
        )
        tts_instance.set_output_format(sample_rate=16000, channels=1)
        session = TTSSession(tts_instance)
        text = "Testing with a saved voice ID."

        await tts_instance.send(text)
        await session.wait_for_result(timeout=15.0)

        assert not session.errors
        assert len(session.speeches) > 0

    @pytest.mark.integration
    async def test_voxtral_tts_with_ref_audio(self):
        import base64
        from pathlib import Path

        sample_path = Path("sample.mp3")
        if not sample_path.exists():
            pytest.skip("sample.mp3 not found for voice cloning test")

        ref_audio = base64.b64encode(sample_path.read_bytes()).decode()
        tts_instance = voxtral.TTS(
            model="voxtral-mini-tts-2603",
            ref_audio=ref_audio,
        )
        tts_instance.set_output_format(sample_rate=16000, channels=1)
        session = TTSSession(tts_instance)
        text = "This speech uses a cloned voice from a reference audio clip."

        await tts_instance.send(text)
        await session.wait_for_result(timeout=20.0)

        assert not session.errors
        assert len(session.speeches) > 0
