#if canImport(CoreAI)
// Wav2Vec2CoreAITranscriber.swift
// English ASR with the Wav2Vec 2.0 Base 960h Core AI export
// (coreai-models/models/wav2vec2/export.py):
//
//   waveform [1, 80000] (5 s @ 16 kHz) → emission [1, T, 29] (CTC logits)
//
// Audio is chunked into 5-second windows (the static export shape), each
// window decoded greedily against torchaudio's WAV2VEC2_ASR_BASE_960H
// character labels, then the chunk texts are stitched together.

import Foundation

final class Wav2Vec2CoreAITranscriber {
    /// torchaudio WAV2VEC2_ASR_BASE_960H labels; index 0 is the CTC blank,
    /// "|" is the word separator.
    private static let labels: [Character] = [
        "-", "|", "E", "T", "A", "O", "N", "I", "H", "S", "R", "D", "L", "U",
        "M", "W", "C", "F", "G", "Y", "P", "B", "V", "K", "'", "X", "J", "Q", "Z"
    ]

    private static let windowSamples = 80_000  // 5 s @ 16 kHz (static export)

    private let model: GraphModel

    init(modelURL: URL) async throws {
        model = try await GraphModel(contentsOf: modelURL, computeUnits: .gpu)
    }

    func transcribe(samples: [Float]) async throws -> String {
        guard !samples.isEmpty else { return "" }

        var pieces: [String] = []
        var start = 0
        while start < samples.count {
            let end = min(start + Self.windowSamples, samples.count)
            var window = Array(samples[start..<end])
            if window.count < Self.windowSamples {
                window.append(
                    contentsOf: [Float](repeating: 0, count: Self.windowSamples - window.count)
                )
            }
            let outputs = try await model.run([
                "waveform": .float32(window, shape: [1, Self.windowSamples])
            ])
            guard let emission = outputs["emission"] else {
                throw NSError(
                    domain: "Wav2Vec2", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Model returned no emission tensor."]
                )
            }
            pieces.append(Self.greedyCTCDecode(emission))
            start += Self.windowSamples
        }

        let joined = pieces.joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        // The model emits uppercase characters; sentence-case for chat.
        return joined.isEmpty ? "" : joined.capitalizedSentence
    }

    /// Greedy CTC: argmax per frame, collapse repeats, drop blanks.
    private static func greedyCTCDecode(_ emission: TensorValue) -> String {
        let logits = emission.floats()
        let vocab = labels.count
        guard emission.shape.count == 3, emission.shape[2] == vocab else { return "" }
        let frames = emission.shape[1]

        var text = ""
        var previous = -1
        for t in 0..<frames {
            let base = t * vocab
            var best = 0
            var bestScore = logits[base]
            for v in 1..<vocab where logits[base + v] > bestScore {
                bestScore = logits[base + v]
                best = v
            }
            if best != previous, best != 0 {
                let char = labels[best]
                text.append(char == "|" ? " " : char)
            }
            previous = best
        }
        return text.trimmingCharacters(in: .whitespaces)
    }
}

extension String {
    /// "HELLO THERE" → "Hello there" (keeps existing apostrophes intact).
    var capitalizedSentence: String {
        let lowercased = self.lowercased()
        guard let first = lowercased.first else { return lowercased }
        return first.uppercased() + lowercased.dropFirst()
    }
}
#endif
