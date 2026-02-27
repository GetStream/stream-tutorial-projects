import asyncio
import contextlib
import io
import logging
import os
import platform
import wave
from typing import Optional

from google import genai
from google.genai import types
from vision_agents.core.processors.base_processor import Processor

from . import events as lyria_events
from .lyria_audio_track import LYRIA_SAMPLE_RATE, LYRIA_CHANNELS

logger = logging.getLogger(__name__)

MODEL_ID = "models/lyria-realtime-exp"
CHUNK_DURATION_SECONDS = 2  # Lyria generates ~2-second chunks
DEFAULT_DURATION_SECONDS = 30


class MusicProcessor(Processor):
    """Google Lyria 3 music generation processor for Vision Agents.

    Connects to the Lyria RealTime API to generate instrumental music
    based on text prompts. Generates 30-second tracks by default, with
    real-time control over style, BPM, density, and brightness.

    Example:
        agent = Agent(
            edge=getstream.Edge(),
            agent_user=User(name="Music AI"),
            instructions="You are a music-generating assistant.",
            llm=openai.LLM("gpt-4o-mini"),
            stt=deepgram.STT(),
            tts=elevenlabs.TTS(),
            processors=[
                lyria.MusicProcessor(
                    initial_prompt="Lo-fi hip hop beats",
                    bpm=85,
                    duration_seconds=30,
                )
            ],
        )
    """

    name = "lyria_music"

    def __init__(
        self,
        api_key: Optional[str] = None,
        initial_prompt: str = "Ambient chill music",
        bpm: int = 90,
        density: float = 0.5,
        brightness: float = 0.5,
        guidance: float = 4.0,
        scale: Optional[str] = None,
        duration_seconds: int = DEFAULT_DURATION_SECONDS,
        output_dir: str = "generated_music",
        **kwargs,
    ):
        """Initialize the Lyria music generation processor.

        Args:
            api_key: Google API key. Uses GOOGLE_API_KEY env var if not provided.
            initial_prompt: Initial music style/genre prompt.
            bpm: Beats per minute (40-180).
            density: Musical note density (0.0-1.0). Higher = busier.
            brightness: Tonal brightness (0.0-1.0). Higher = crisper.
            guidance: How strictly the model follows prompts (0.0-6.0).
            scale: Musical scale (e.g., "C_MAJOR_A_MINOR"). None for auto.
            duration_seconds: Duration of generated music (default 30s).
            output_dir: Directory for saving generated WAV files.
        """
        self.api_key = api_key or os.getenv("GOOGLE_API_KEY")
        if not self.api_key:
            raise ValueError(
                "Google API key is required. Set GOOGLE_API_KEY environment variable "
                "or pass api_key parameter."
            )

        self.initial_prompt = initial_prompt
        self.bpm = max(40, min(180, bpm))
        self.density = max(0.0, min(1.0, density))
        self.brightness = max(0.0, min(1.0, brightness))
        self.guidance = max(0.0, min(6.0, guidance))
        self.scale = scale
        self.duration_seconds = duration_seconds
        self.output_dir = output_dir

        self._client = genai.Client(
            api_key=self.api_key,
            http_options={"api_version": "v1alpha"},
        )

        self._generating = False
        self._generation_task: Optional[asyncio.Task] = None
        self._current_prompt = initial_prompt
        self._weighted_prompts: list[types.WeightedPrompt] = [
            types.WeightedPrompt(text=initial_prompt, weight=1.0)
        ]
        self._agent = None
        self._session = None

        os.makedirs(output_dir, exist_ok=True)

        logger.info(
            f"Lyria MusicProcessor initialized "
            f"(prompt: {initial_prompt[:50]}..., bpm: {bpm}, "
            f"duration: {duration_seconds}s)"
        )

    def attach_agent(self, agent) -> None:
        """Register custom events and function calls with the agent."""
        self._agent = agent

        agent.events.register(
            lyria_events.LyriaMusicGenerationStartedEvent,
            lyria_events.LyriaMusicGenerationChunkEvent,
            lyria_events.LyriaMusicGenerationCompletedEvent,
            lyria_events.LyriaMusicGenerationErrorEvent,
            lyria_events.LyriaPromptChangedEvent,
            lyria_events.LyriaConnectionStateEvent,
        )

    async def generate_music(
        self,
        prompt: Optional[str] = None,
        duration_seconds: Optional[int] = None,
    ) -> str:
        """Generate a music track based on a text prompt.

        Args:
            prompt: Music style prompt. Uses initial_prompt if not provided.
            duration_seconds: Override default duration.

        Returns:
            Path to the generated WAV file.
        """
        if self._generating:
            logger.warning("Music generation already in progress")
            return "Generation already in progress. Please wait."

        prompt = prompt or self._current_prompt
        duration = duration_seconds or self.duration_seconds
        max_chunks = int(duration / CHUNK_DURATION_SECONDS)

        self._generating = True
        self._current_prompt = prompt
        self._weighted_prompts = self._parse_prompt(prompt)

        if self._agent:
            self._agent.events.send(
                lyria_events.LyriaMusicGenerationStartedEvent(
                    plugin_name=self.name,
                    prompt=prompt,
                    bpm=self.bpm,
                    duration_seconds=duration,
                )
            )

        output_path = ""
        try:
            output_path = await self._run_generation(
                prompts=self._weighted_prompts,
                max_chunks=max_chunks,
                duration=duration,
            )
        except asyncio.CancelledError:
            logger.warning("Music generation was cancelled")
            return "Music generation was cancelled"
        except BaseException as e:
            logger.exception(f"Music generation failed: {type(e).__name__}: {e}")
            if self._agent:
                self._agent.events.send(
                    lyria_events.LyriaMusicGenerationErrorEvent(
                        plugin_name=self.name,
                        error_message=f"{type(e).__name__}: {e}",
                        prompt=prompt,
                    )
                )
            return f"Error generating music: {type(e).__name__}: {e}"
        finally:
            self._generating = False

        return output_path

    async def generate_music_async(
        self,
        prompt: Optional[str] = None,
        duration_seconds: Optional[int] = None,
    ) -> None:
        """Start music generation as a background task."""
        if self._generation_task and not self._generation_task.done():
            logger.warning("Cancelling previous generation task")
            self._generation_task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await self._generation_task

        async def _run():
            try:
                result = await self.generate_music(
                    prompt=prompt, duration_seconds=duration_seconds
                )
                logger.info(f"Background music generation result: {result}")
            except Exception as e:
                logger.exception(f"Background music generation failed: {e}")

        self._generation_task = asyncio.create_task(_run())

    async def update_prompt(self, prompt: str, weight: float = 1.0) -> None:
        """Update the music style prompt.

        Args:
            prompt: New music style/genre prompt.
            weight: Prompt influence weight (default 1.0).
        """
        old_prompt = self._current_prompt
        self._current_prompt = prompt
        self._weighted_prompts = [types.WeightedPrompt(text=prompt, weight=weight)]

        if self._agent:
            self._agent.events.send(
                lyria_events.LyriaPromptChangedEvent(
                    plugin_name=self.name,
                    old_prompt=old_prompt,
                    new_prompt=prompt,
                )
            )

        logger.info(f"Updated Lyria prompt: {prompt[:50]}...")

    async def set_weighted_prompts(
        self, prompts: list[dict[str, object]]
    ) -> None:
        """Set multiple weighted prompts for blending musical styles.

        Args:
            prompts: List of dicts with 'text' and 'weight' keys.
                     Example: [{"text": "Jazz", "weight": 0.7},
                              {"text": "Electronic", "weight": 0.3}]
        """
        self._weighted_prompts = [
            types.WeightedPrompt(text=str(p["text"]), weight=float(p.get("weight", 1.0)))
            for p in prompts
        ]
        combined = ", ".join(f"{p['text']}:{p.get('weight', 1.0)}" for p in prompts)
        self._current_prompt = combined
        logger.info(f"Set weighted prompts: {combined}")

    async def set_config(
        self,
        bpm: Optional[int] = None,
        density: Optional[float] = None,
        brightness: Optional[float] = None,
        guidance: Optional[float] = None,
        scale: Optional[str] = None,
    ) -> None:
        """Update music generation configuration.

        Args:
            bpm: Beats per minute (40-180).
            density: Note density (0.0-1.0).
            brightness: Tonal brightness (0.0-1.0).
            guidance: Prompt adherence (0.0-6.0).
            scale: Musical scale string.
        """
        if bpm is not None:
            self.bpm = max(40, min(180, bpm))
        if density is not None:
            self.density = max(0.0, min(1.0, density))
        if brightness is not None:
            self.brightness = max(0.0, min(1.0, brightness))
        if guidance is not None:
            self.guidance = max(0.0, min(6.0, guidance))
        if scale is not None:
            self.scale = scale

        logger.info(
            f"Updated config: bpm={self.bpm}, density={self.density}, "
            f"brightness={self.brightness}, guidance={self.guidance}"
        )

    def _parse_prompt(self, prompt_text: str) -> list[types.WeightedPrompt]:
        """Parse a prompt string into weighted prompts.

        Supports formats:
            "jazz" -> single prompt with weight 1.0
            "jazz:0.7, electronic:0.3" -> multiple weighted prompts
        """
        if ":" in prompt_text:
            prompts = []
            for segment in prompt_text.split(","):
                segment = segment.strip()
                if not segment:
                    continue
                parts = segment.split(":", 1)
                if len(parts) == 2:
                    text = parts[0].strip()
                    try:
                        weight = float(parts[1].strip())
                        prompts.append(types.WeightedPrompt(text=text, weight=weight))
                    except ValueError:
                        prompts.append(types.WeightedPrompt(text=segment, weight=1.0))
                else:
                    prompts.append(types.WeightedPrompt(text=segment, weight=1.0))

            if prompts:
                return prompts

        return [types.WeightedPrompt(text=prompt_text, weight=1.0)]

    def _build_generation_config(self) -> types.LiveMusicGenerationConfig:
        """Build the Lyria music generation config from current settings."""
        config_kwargs: dict = {
            "bpm": self.bpm,
            "density": self.density,
            "brightness": self.brightness,
            "guidance": self.guidance,
        }
        if self.scale:
            config_kwargs["scale"] = self.scale

        return types.LiveMusicGenerationConfig(**config_kwargs)

    async def _run_generation(
        self,
        prompts: list[types.WeightedPrompt],
        max_chunks: int,
        duration: int,
    ) -> str:
        """Connect to Lyria RealTime and generate music.

        Returns the path to the saved WAV file.
        """
        if self._agent:
            self._agent.events.send(
                lyria_events.LyriaConnectionStateEvent(
                    plugin_name=self.name, state="connecting"
                )
            )

        audio_buffer = io.BytesIO()
        total_chunks = 0
        total_bytes = 0

        async with self._client.aio.live.music.connect(model=MODEL_ID) as session:
            self._session = session

            if self._agent:
                self._agent.events.send(
                    lyria_events.LyriaConnectionStateEvent(
                        plugin_name=self.name, state="connected"
                    )
                )

            await session.set_weighted_prompts(prompts=prompts)

            config = self._build_generation_config()
            await session.set_music_generation_config(config=config)

            await session.play()

            logger.info(
                f"Lyria generation started: {max_chunks} chunks "
                f"(~{duration}s), bpm={self.bpm}"
            )

            async for message in session.receive():
                if total_chunks >= max_chunks:
                    break

                try:
                    server_content = getattr(message, "server_content", None)
                    if server_content is None:
                        continue

                    audio_chunks = getattr(server_content, "audio_chunks", None)
                    if not audio_chunks:
                        continue

                    audio_data = audio_chunks[0].data
                    if audio_data is None:
                        continue
                except (AttributeError, IndexError, TypeError) as e:
                    logger.debug(f"Skipping non-audio message: {e}")
                    continue

                audio_buffer.write(audio_data)
                total_chunks += 1
                total_bytes += len(audio_data)

                if total_chunks % 5 == 0 or total_chunks == 1:
                    logger.info(
                        f"Lyria chunk {total_chunks}/{max_chunks} "
                        f"({total_bytes} bytes so far)"
                    )

                await asyncio.sleep(1e-12)

            logger.info(
                f"Lyria generation complete: {total_chunks} chunks, "
                f"{total_bytes} bytes"
            )

            self._session = None

        if self._agent:
            self._agent.events.send(
                lyria_events.LyriaConnectionStateEvent(
                    plugin_name=self.name, state="disconnected"
                )
            )

        prompt_slug = "".join(
            c if c.isalnum() or c in "-_ " else "" for c in self._current_prompt
        )[:40].strip().replace(" ", "_")
        output_filename = f"lyria_{prompt_slug}_{self.bpm}bpm.wav"
        output_path = os.path.join(self.output_dir, output_filename)

        audio_bytes = audio_buffer.getvalue()
        with wave.open(output_path, "wb") as wf:
            wf.setnchannels(LYRIA_CHANNELS)
            wf.setsampwidth(2)  # 16-bit
            wf.setframerate(LYRIA_SAMPLE_RATE)
            wf.writeframes(audio_bytes)

        logger.info(
            f"Music saved to {output_path} "
            f"({total_chunks} chunks, {total_bytes} bytes)"
        )

        if self._agent:
            self._agent.events.send(
                lyria_events.LyriaMusicGenerationCompletedEvent(
                    plugin_name=self.name,
                    prompt=self._current_prompt,
                    duration_seconds=duration,
                    output_file=output_path,
                    total_chunks=total_chunks,
                    total_bytes=total_bytes,
                )
            )

        await self._play_audio(output_path)

        return output_path

    async def _play_audio(self, filepath: str) -> None:
        """Play the generated WAV file using the system audio player."""
        system = platform.system()
        if system == "Darwin":
            cmd = ["afplay", filepath]
        elif system == "Linux":
            cmd = ["aplay", filepath]
        elif system == "Windows":
            cmd = ["powershell", "-c", f'(New-Object Media.SoundPlayer "{filepath}").PlaySync()']
        else:
            logger.warning(f"Auto-play not supported on {system}")
            return

        logger.info(f"Playing generated music: {filepath}")
        try:
            proc = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.DEVNULL,
                stderr=asyncio.subprocess.PIPE,
            )
            _, stderr = await proc.communicate()
            if proc.returncode != 0:
                logger.warning(f"Audio playback exited with code {proc.returncode}: {stderr.decode().strip()}")
        except FileNotFoundError:
            logger.warning(f"Audio player not found ({cmd[0]}), skipping playback")
        except Exception as e:
            logger.warning(f"Audio playback failed: {e}")

    async def close(self) -> None:
        """Clean up resources."""
        self._generating = False

        if self._generation_task and not self._generation_task.done():
            self._generation_task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await self._generation_task

        self._session = None
        logger.info("Lyria MusicProcessor closed")
