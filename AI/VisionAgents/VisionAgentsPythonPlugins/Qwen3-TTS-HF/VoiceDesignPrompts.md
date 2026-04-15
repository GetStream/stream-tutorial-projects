# Voice Design Prompts for Qwen3-TTS

Voice design lets you create novel voices entirely from natural-language descriptions using the [`Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign`](https://huggingface.co/Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign) model. Instead of picking a preset speaker or cloning from audio, you describe the voice you want and the model synthesizes it.

## Example Prompts

1. **Funny Alien** — A funny alien creature with a ludicrous, annoying, high-pitched voice that constantly gargles slightly, as if speaking through bubbling liquid. The tone is silly, squeaky, and nasal with an erratic, unpredictable cadence. Non-human and cartoonish, with exaggerated inflections that rise and fall wildly mid-sentence.

2. **African-American Grandma** — An elderly female grandmother, 80 years old, with a high-pitched, thin, croaky old woman's voice. She sounds cranky and shrill, with a scratchy, nasal, feminine tone that wavers with age. Her speech is slow with sharp, irritable emphasis. The voice is distinctly an old lady's — reedy, quavering, and breathless, with a warm Southern African-American cadence.

3. **Mystical God** — A powerful male god with an immensely deep, booming, resonant bass voice that reverberates as if echoing through a vast marble temple. The tone is charming, proud, and strong with a theatrical, grandiose delivery. He speaks slowly and deliberately, savoring each word with regal authority. The voice carries warmth beneath its overwhelming power, with rich, velvety low tones and a commanding, larger-than-life presence.

4. **Warrior** — A calm, husky male voice with a thick Japanese accent speaking English. The tone is soft, whiskery, and low, with a composed and gentle pacing. He speaks quietly and deliberately, with a breathy, understated quality. Each word is placed carefully with measured pauses between phrases. The voice is warm but reserved, like a whisper carried on a still wind.

5. **Assertive Female** — A low, whispery, assertive female voice with a thick French accent speaking English. Cool, composed, and subtly seductive with a hint of mystery in every phrase. The tone is intimate and breathy, spoken close to the microphone with a smooth, velvety texture. She speaks with unhurried confidence, letting words linger slightly. The French accent softens consonants and adds a melodic, lilting quality to the phrasing.

6. **Scary Old Woman** — A scary old woman with a croaky, harsh, shrill, high-pitched voice that sounds like a wicked witch. She cackles between words, with a menacing, sneaky undertone. The voice is thin, raspy, and cracked with age, rising to piercing shrieks on emphasized words. She speaks with a creeping, slow pace that suddenly lurches into frantic, cackling bursts. Haggard and sinister, as if whispering dark secrets through rotting teeth.

---

## Best Practices

### Structure your descriptions in layers

Effective voice design prompts stack multiple descriptive dimensions. Aim to cover most of these in your `instruct` text:

| Layer | What to describe | Examples |
|-------|-----------------|----------|
| **Identity** | Gender, age, character archetype | "An elderly female grandmother, 80 years old" |
| **Pitch & register** | High, mid-range, deep, bass | "A deep, booming, resonant bass voice" |
| **Texture & timbre** | Breathy, raspy, smooth, nasal, husky | "Thin, raspy, and cracked with age" |
| **Emotion & personality** | Warm, angry, menacing, cheerful, proud | "Cool, composed, and subtly seductive" |
| **Pacing & cadence** | Slow, fast, deliberate, erratic | "Speaks slowly and deliberately, savoring each word" |
| **Accent & dialect** | Regional or cultural influence | "A thick French accent that softens consonants" |
| **Distinguishing details** | Unique mannerisms, metaphors, imagery | "As if echoing through a vast marble temple" |

### Be specific and vivid

The VoiceDesign model inherits strong text comprehension from Qwen3's language model foundation and uses an internal thinking process to parse complex descriptions. Concrete, sensory language produces better results than abstract labels.

- **Weak:** "An old man's voice"
- **Strong:** "An elderly man in his 80s with a reedy, quavering voice that wavers with age, slow and breathless, with a warm scratchy quality"

### Use 2-4 sentences

The examples that work well in this project use 2-4 sentences (roughly 40-80 words). This gives the model enough signal without overwhelming it. Extremely short prompts ("deep male voice") lack specificity; extremely long prompts risk conflicting attributes.

### Describe acoustic qualities, not just personality

The model controls timbre, pitch, and prosody — not semantic content. Focus on how the voice *sounds*, not what the character *would say*.

- **Less effective:** "A wise philosopher who quotes Aristotle"
- **More effective:** "A calm, measured male voice with a deep, resonant tone and slow, contemplative pacing"

### Specify the language context when using accents

When designing a voice with a non-native accent, state both the accent origin and the target language. This helps the model blend accent characteristics correctly.

- "A calm, husky male voice with a thick Japanese accent **speaking English**"
- "A whispery female voice with a thick French accent **speaking English**"

### One voice per prompt

Each `instruct` prompt creates a single voice persona. Don't describe a conversation between two characters or blend multiple speakers into one description.

### Test and iterate

Voice design is generative — the model creates a novel voice each time. If the first result doesn't match your mental model, try adjusting specific attributes (e.g., shift "low-pitched" to "mid-range", change "fast-paced" to "slow and deliberate"). Small wording changes can meaningfully shift the output.

---

## Limitations

### Model availability

- Voice design is **only available with the 1.7B VoiceDesign model** (`Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign`). There is no 0.6B variant for voice design.
- This is a separate model from CustomVoice and Base — you cannot mix voice design with preset speakers or voice cloning in a single model load.

### Voice consistency across calls

- The VoiceDesign model generates a **novel voice from the description on every call**. There is no speaker ID or embedding to anchor the voice, so the exact voice characteristics may vary slightly between generations even with the same prompt.
- For consistent voice identity across a session, use CustomVoice (preset speakers) or Base (voice cloning from a reference clip) instead.

### Language support

- The model supports **10 languages**: Chinese, English, Japanese, Korean, German, French, Russian, Portuguese, Spanish, and Italian.
- Voice design performs best in **Chinese and English**. Descriptions targeting other languages may produce voices with reduced expressiveness or accuracy in following complex attribute instructions.
- Languages outside the supported 10 are not supported and may produce unintelligible output.

### Instruction-following fidelity

- While Qwen3-TTS VoiceDesign achieves state-of-the-art open-source results on the [InstructTTSEval benchmark](https://arxiv.org/abs/2601.15621) (82.9% APS, 82.4% DSD, 68.4% RP in English), not every attribute in a complex description will be perfectly realized.
- Conflicting attributes (e.g., "high-pitched deep bass") will produce unpredictable results — the model may favor one attribute over the other.
- Very abstract or fictional vocal qualities (e.g., "sounds like thunder mixed with a violin") may not translate directly into acoustic changes. The model handles concrete speech attributes (pitch, pace, breathiness, age) more reliably than poetic metaphors.

### Hardware requirements

- **CUDA GPU strongly recommended.** The 1.7B VoiceDesign model requires ~4 GB VRAM in bfloat16.
- **Apple Silicon (MPS) not directly supported** — falls back to CPU with float32, producing 15-40+ seconds per utterance.
- **FlashAttention 2 requires CUDA** with Ampere architecture or newer (RTX 30xx+).

### No fine-grained phonetic control

- Voice design controls timbre, prosody, and speaking style. It does **not** provide phoneme-level control (e.g., specific pronunciation corrections, phonetic spelling, or SSML-style markup).
- For precise prosody adjustments on a known voice, use CustomVoice mode with the `instruct` parameter instead.

---

## Resources

- [Qwen3-TTS Technical Report (arXiv 2601.15621)](https://arxiv.org/abs/2601.15621)
- [Qwen3-TTS VoiceDesign on HuggingFace](https://huggingface.co/Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign)
- [Qwen3-TTS Blog Post](https://qwen.ai/blog?id=qwen3tts-0115)
- [Qwen3-TTS GitHub](https://github.com/QwenLM/Qwen3-TTS)
- [InstructTTSEval Benchmark](https://arxiv.org/abs/2506.16381)

Source for original prompt ideas: https://elevenlabs.io/voice-design
