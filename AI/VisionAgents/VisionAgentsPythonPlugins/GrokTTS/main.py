"""
Grok TTS Plugin for Vision Agents

A custom Python text-to-speech (TTS) plugin that connects xAI's Grok Voice API
with Vision Agents, enabling expressive speech synthesis with any AI provider.

Voices: Eve, Ara, Leo, Rex, Sal

See plugins/grok_tts/ for the full plugin implementation and examples.
"""


def main():
    from vision_agents.plugins.grok_tts import TTS, VOICE_DESCRIPTIONS

    print("Grok TTS Plugin for Vision Agents")
    print("=" * 42)
    print()
    print("Available voices:")
    for voice_id, description in VOICE_DESCRIPTIONS.items():
        print(f"  {voice_id:5s}  {description}")
    print()
    print("Plugin location: plugins/grok_tts/")
    print("Examples:        plugins/grok_tts/example/")
    print()
    print("Run an example:")
    print("  cd plugins/grok_tts/example")
    print("  uv sync")
    print("  uv run basic_example.py run")


if __name__ == "__main__":
    main()
