import asyncio
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from vision_agents.plugins.lyria.lyria_music_processor import MusicProcessor
from vision_agents.plugins.lyria.lyria_audio_track import LyriaAudioTrack
from vision_agents.plugins.lyria import events as lyria_events


@pytest.fixture
def api_key():
    return "test-api-key-for-lyria"


@pytest.fixture
def processor(api_key):
    with patch.dict("os.environ", {"GOOGLE_API_KEY": api_key}):
        return MusicProcessor(
            api_key=api_key,
            initial_prompt="test jazz",
            bpm=120,
            duration_seconds=10,
        )


class TestMusicProcessorInit:
    def test_init_with_api_key(self, api_key):
        proc = MusicProcessor(api_key=api_key)
        assert proc.api_key == api_key
        assert proc.name == "lyria_music"

    def test_init_from_env(self):
        with patch.dict("os.environ", {"GOOGLE_API_KEY": "env-key"}):
            proc = MusicProcessor()
            assert proc.api_key == "env-key"

    def test_init_missing_api_key(self):
        with patch.dict("os.environ", {}, clear=True):
            with pytest.raises(ValueError, match="Google API key is required"):
                MusicProcessor()

    def test_init_default_values(self, api_key):
        proc = MusicProcessor(api_key=api_key)
        assert proc.initial_prompt == "Ambient chill music"
        assert proc.bpm == 90
        assert proc.density == 0.5
        assert proc.brightness == 0.5
        assert proc.guidance == 4.0
        assert proc.duration_seconds == 30

    def test_init_custom_values(self, api_key):
        proc = MusicProcessor(
            api_key=api_key,
            initial_prompt="Heavy Metal",
            bpm=160,
            density=0.9,
            brightness=0.8,
            guidance=5.0,
            scale="C_MAJOR_A_MINOR",
            duration_seconds=15,
        )
        assert proc.initial_prompt == "Heavy Metal"
        assert proc.bpm == 160
        assert proc.density == 0.9
        assert proc.brightness == 0.8
        assert proc.guidance == 5.0
        assert proc.scale == "C_MAJOR_A_MINOR"
        assert proc.duration_seconds == 15

    def test_bpm_clamping(self, api_key):
        proc = MusicProcessor(api_key=api_key, bpm=200)
        assert proc.bpm == 180

        proc2 = MusicProcessor(api_key=api_key, bpm=10)
        assert proc2.bpm == 40

    def test_density_clamping(self, api_key):
        proc = MusicProcessor(api_key=api_key, density=2.0)
        assert proc.density == 1.0

        proc2 = MusicProcessor(api_key=api_key, density=-0.5)
        assert proc2.density == 0.0


class TestPromptParsing:
    def test_simple_prompt(self, processor):
        prompts = processor._parse_prompt("jazz")
        assert len(prompts) == 1
        assert prompts[0].text == "jazz"
        assert prompts[0].weight == 1.0

    def test_weighted_prompts(self, processor):
        prompts = processor._parse_prompt("jazz:0.7, electronic:0.3")
        assert len(prompts) == 2
        assert prompts[0].text == "jazz"
        assert prompts[0].weight == 0.7
        assert prompts[1].text == "electronic"
        assert prompts[1].weight == 0.3

    def test_mixed_weight_format(self, processor):
        prompts = processor._parse_prompt("piano:2.0, meditation:0.5, live:1.0")
        assert len(prompts) == 3
        assert prompts[0].weight == 2.0
        assert prompts[1].weight == 0.5
        assert prompts[2].weight == 1.0


class TestConfigUpdates:
    @pytest.mark.asyncio
    async def test_update_prompt(self, processor):
        await processor.update_prompt("rock")
        assert processor._current_prompt == "rock"
        assert len(processor._weighted_prompts) == 1
        assert processor._weighted_prompts[0].text == "rock"

    @pytest.mark.asyncio
    async def test_set_weighted_prompts(self, processor):
        await processor.set_weighted_prompts([
            {"text": "Jazz", "weight": 0.7},
            {"text": "Electronic", "weight": 0.3},
        ])
        assert len(processor._weighted_prompts) == 2
        assert processor._weighted_prompts[0].text == "Jazz"
        assert processor._weighted_prompts[0].weight == 0.7

    @pytest.mark.asyncio
    async def test_set_config(self, processor):
        await processor.set_config(bpm=140, density=0.8, brightness=0.3)
        assert processor.bpm == 140
        assert processor.density == 0.8
        assert processor.brightness == 0.3

    @pytest.mark.asyncio
    async def test_set_config_clamping(self, processor):
        await processor.set_config(bpm=999, density=5.0)
        assert processor.bpm == 180
        assert processor.density == 1.0


class TestAudioTrack:
    def test_audio_track_init(self):
        track = LyriaAudioTrack()
        assert track.sample_rate == 48000
        assert track.channels == 2
        assert not track.is_stopped

    @pytest.mark.asyncio
    async def test_add_audio_chunk(self):
        track = LyriaAudioTrack()
        chunk = b"\x00" * 1024
        await track.add_audio_chunk(chunk)
        assert not track._queue.empty()

    def test_stop(self):
        track = LyriaAudioTrack()
        track.stop()
        assert track.is_stopped


class TestClose:
    @pytest.mark.asyncio
    async def test_close(self, processor):
        await processor.close()
        assert not processor._generating
        assert processor._audio_track.is_stopped


class TestEvents:
    def test_event_types(self):
        started = lyria_events.LyriaMusicGenerationStartedEvent()
        assert started.type == "plugin.lyria.music_generation_started"

        completed = lyria_events.LyriaMusicGenerationCompletedEvent()
        assert completed.type == "plugin.lyria.music_generation_completed"

        error = lyria_events.LyriaMusicGenerationErrorEvent()
        assert error.type == "plugin.lyria.music_generation_error"

        chunk = lyria_events.LyriaMusicGenerationChunkEvent()
        assert chunk.type == "plugin.lyria.music_generation_chunk"

        prompt = lyria_events.LyriaPromptChangedEvent()
        assert prompt.type == "plugin.lyria.prompt_changed"

        conn = lyria_events.LyriaConnectionStateEvent()
        assert conn.type == "plugin.lyria.connection_state"

    def test_event_fields(self):
        event = lyria_events.LyriaMusicGenerationStartedEvent(
            plugin_name="lyria_music",
            prompt="jazz",
            bpm=120,
            duration_seconds=30,
        )
        assert event.prompt == "jazz"
        assert event.bpm == 120
        assert event.duration_seconds == 30
