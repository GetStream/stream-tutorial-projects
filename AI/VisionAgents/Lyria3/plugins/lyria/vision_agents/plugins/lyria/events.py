from dataclasses import dataclass, field
from typing import Optional

from vision_agents.core.events import PluginBaseEvent


@dataclass
class LyriaMusicGenerationStartedEvent(PluginBaseEvent):
    """Emitted when music generation begins."""

    type: str = field(default="plugin.lyria.music_generation_started", init=False)
    prompt: str = ""
    bpm: Optional[int] = None
    duration_seconds: int = 30


@dataclass
class LyriaMusicGenerationChunkEvent(PluginBaseEvent):
    """Emitted for each audio chunk received from Lyria."""

    type: str = field(default="plugin.lyria.music_generation_chunk", init=False)
    chunk_index: int = 0
    chunk_size_bytes: int = 0


@dataclass
class LyriaMusicGenerationCompletedEvent(PluginBaseEvent):
    """Emitted when a 30-second music generation completes."""

    type: str = field(default="plugin.lyria.music_generation_completed", init=False)
    prompt: str = ""
    duration_seconds: int = 30
    output_file: Optional[str] = None
    total_chunks: int = 0
    total_bytes: int = 0


@dataclass
class LyriaMusicGenerationErrorEvent(PluginBaseEvent):
    """Emitted when music generation encounters an error."""

    type: str = field(default="plugin.lyria.music_generation_error", init=False)
    error_message: str = ""
    prompt: str = ""


@dataclass
class LyriaPromptChangedEvent(PluginBaseEvent):
    """Emitted when the music style prompt is updated."""

    type: str = field(default="plugin.lyria.prompt_changed", init=False)
    old_prompt: str = ""
    new_prompt: str = ""


@dataclass
class LyriaConnectionStateEvent(PluginBaseEvent):
    """Emitted when the Lyria session connection state changes."""

    type: str = field(default="plugin.lyria.connection_state", init=False)
    state: str = ""
