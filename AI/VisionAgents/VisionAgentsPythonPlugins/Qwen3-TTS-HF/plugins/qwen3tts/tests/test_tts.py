"""Unit tests for the Qwen3-TTS Vision Agents plugin."""

import pytest

from plugins.qwen3tts.vision_agents.plugins.qwen3tts import (
    TTS,
    MODEL_BASE_0_6B,
    MODEL_BASE_1_7B,
    MODEL_CUSTOM_VOICE_0_6B,
    MODEL_CUSTOM_VOICE_1_7B,
    MODEL_VOICE_DESIGN,
    SPEAKERS,
    SUPPORTED_LANGUAGES,
)


def test_default_init():
    """TTS initializes with sensible defaults (no model loaded yet)."""
    tts = TTS()
    assert tts.model_id == MODEL_CUSTOM_VOICE_1_7B
    assert tts.mode == "custom_voice"
    assert tts.speaker == "Vivian"
    assert tts.language == "Auto"
    assert tts._model is None


def test_custom_voice_init():
    """TTS initializes for custom voice mode with specific speaker."""
    tts = TTS(
        model=MODEL_CUSTOM_VOICE_0_6B,
        mode="custom_voice",
        speaker="Ryan",
        language="English",
    )
    assert tts.model_id == MODEL_CUSTOM_VOICE_0_6B
    assert tts.speaker == "Ryan"
    assert tts.language == "English"


def test_voice_design_init():
    """TTS initializes for voice design mode."""
    tts = TTS(
        model=MODEL_VOICE_DESIGN,
        mode="voice_design",
        instruct="Young cheerful female voice.",
    )
    assert tts.mode == "voice_design"
    assert tts.instruct == "Young cheerful female voice."


def test_voice_clone_init():
    """TTS initializes for voice clone mode."""
    tts = TTS(
        model=MODEL_BASE_1_7B,
        mode="voice_clone",
        ref_audio="https://example.com/ref.wav",
        ref_text="Hello world.",
    )
    assert tts.mode == "voice_clone"
    assert tts.ref_audio == "https://example.com/ref.wav"
    assert tts.ref_text == "Hello world."


def test_speakers_list():
    """All 9 built-in speakers are registered."""
    assert len(SPEAKERS) == 9
    assert "Vivian" in SPEAKERS
    assert "Ryan" in SPEAKERS
    assert "Ono_Anna" in SPEAKERS


def test_supported_languages():
    """All 10 languages plus Auto are registered."""
    assert len(SUPPORTED_LANGUAGES) == 11
    assert "Chinese" in SUPPORTED_LANGUAGES
    assert "English" in SUPPORTED_LANGUAGES
    assert "Auto" in SUPPORTED_LANGUAGES


def test_model_constants():
    """Model ID constants match expected HuggingFace paths."""
    assert "1.7B-CustomVoice" in MODEL_CUSTOM_VOICE_1_7B
    assert "0.6B-CustomVoice" in MODEL_CUSTOM_VOICE_0_6B
    assert "VoiceDesign" in MODEL_VOICE_DESIGN
    assert "1.7B-Base" in MODEL_BASE_1_7B
    assert "0.6B-Base" in MODEL_BASE_0_6B


@pytest.mark.asyncio
async def test_voice_design_requires_instruct():
    """voice_design mode raises if instruct is missing."""
    tts = TTS(model=MODEL_VOICE_DESIGN, mode="voice_design")
    tts._model = object()  # fake model to bypass loading
    with pytest.raises(ValueError, match="instruct is required"):
        tts._generate_voice_design("Hello")


@pytest.mark.asyncio
async def test_voice_clone_requires_ref_audio():
    """voice_clone mode raises if ref_audio is missing."""
    tts = TTS(model=MODEL_BASE_1_7B, mode="voice_clone")
    tts._model = object()
    with pytest.raises(ValueError, match="ref_audio is required"):
        tts._generate_voice_clone("Hello")
