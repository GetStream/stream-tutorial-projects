import asyncio
import json
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
import pytest_asyncio

from vision_agents.plugins.vibevoice.tts import TTS


@pytest.fixture
def tts_instance():
    return TTS(
        base_url="http://localhost:3000",
        voice="en-Carter_man",
        cfg_scale=1.5,
        inference_steps=5,
    )


class TestTTSInit:
    def test_defaults(self):
        tts = TTS()
        assert tts.base_url == "http://localhost:3000"
        assert tts.voice is None
        assert tts.cfg_scale == 1.5
        assert tts.sample_rate == 24_000

    def test_custom_params(self):
        tts = TTS(
            base_url="http://myserver:8000",
            voice="en-Wayne_man",
            cfg_scale=2.0,
            inference_steps=10,
            sample_rate=24000,
        )
        assert tts.base_url == "http://myserver:8000"
        assert tts.voice == "en-Wayne_man"
        assert tts.cfg_scale == 2.0
        assert tts.inference_steps == 10

    def test_env_var_fallback(self, monkeypatch):
        monkeypatch.setenv("VIBEVOICE_BASE_URL", "http://env-server:5000")
        tts = TTS()
        assert tts.base_url == "http://env-server:5000"

    def test_trailing_slash_stripped(self):
        tts = TTS(base_url="http://localhost:3000/")
        assert tts.base_url == "http://localhost:3000"


class TestWSURL:
    def test_basic_url(self, tts_instance):
        url = tts_instance._build_ws_url("Hello world")
        assert url.startswith("ws://localhost:3000/stream?")
        assert "text=Hello" in url
        assert "cfg=1.5" in url
        assert "steps=5" in url
        assert "voice=en-Carter_man" in url

    def test_no_optional_params(self):
        tts = TTS(base_url="http://localhost:3000")
        url = tts._build_ws_url("Test")
        assert "voice" not in url
        assert "steps" not in url


class TestStopAudio:
    @pytest.mark.asyncio
    async def test_stop_sets_event(self, tts_instance):
        assert not tts_instance._stop_event.is_set()
        await tts_instance.stop_audio()
        assert tts_instance._stop_event.is_set()


class TestClose:
    @pytest.mark.asyncio
    async def test_close_without_client(self, tts_instance):
        await tts_instance.close()
        assert tts_instance._http_client is None

    @pytest.mark.asyncio
    async def test_close_with_client(self, tts_instance):
        await tts_instance._ensure_http_client()
        assert tts_instance._http_client is not None
        await tts_instance.close()
        assert tts_instance._http_client is None
