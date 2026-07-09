#if canImport(CoreAI)
// WhisperCoreAITranscriber.swift
// Speech recognition with OpenAI Whisper Core AI exports
// (coreai-models/models/whisper/export.py):
//
//   input_features [1, 128, 3000] + decoder_input_ids [1, n] → logits [1, n, vocab]
//
// The full pipeline is implemented on-device:
//   1. 16 kHz mono audio → 128-bin log-Mel spectrogram (Slaney filterbank,
//      Hann window, n_fft 400, hop 160 — Whisper's exact preprocessing).
//   2. Greedy autoregressive decode from
//      <|startoftranscript|><|en|><|transcribe|><|notimestamps|>.
//   3. Byte-level BPE detokenization with the Whisper vocab.json
//      (fetched once from Hugging Face and cached in Documents).
//
// Works with exports whose decoder length is dynamic, or static with a
// window > 1 (causal attention makes right-padding safe). The default
// recipe exports a 1-token static decoder; in that case a descriptive
// error asks for a dynamic re-export.

import Accelerate
import Foundation

final class WhisperCoreAITranscriber {
    // Whisper audio front-end constants (large-v3 family).
    private static let sampleRate = 16_000
    private static let nFFT = 400
    private static let hopLength = 160
    private static let nMels = 128
    private static let chunkSamples = 30 * sampleRate    // 480 000
    private static let nFrames = 3000

    // Multilingual large-v3 special tokens.
    private static let tokenEOT: Int32 = 50257
    private static let tokenSOT: Int32 = 50258
    private static let tokenEnglish: Int32 = 50259
    private static let tokenTranscribe: Int32 = 50360
    private static let tokenNoTimestamps: Int32 = 50364
    private static let maxNewTokens = 96

    private let model: GraphModel
    private let vocabulary: [Int: String]

    init(modelURL: URL) async throws {
        model = try await GraphModel(contentsOf: modelURL, computeUnits: .gpu)
        vocabulary = try await Self.loadVocabulary()
    }

    func transcribe(samples: [Float]) async throws -> String {
        guard !samples.isEmpty else { return "" }
        let mel = Self.logMelSpectrogram(samples: samples)

        let declared = model.shape(ofInput: "decoder_input_ids") ?? [1, 1]
        let staticWindow = declared.count == 2 && declared[1] > 0 ? declared[1] : nil
        if let window = staticWindow, window <= 1 {
            throw NSError(
                domain: "Whisper", code: 1,
                userInfo: [NSLocalizedDescriptionKey:
                    "This Whisper export has a fixed 1-token decoder and cannot "
                    + "transcribe. Re-export with a dynamic decoder length "
                    + "(see coreai-models/models/whisper)."]
            )
        }

        var tokens: [Int32] = [
            Self.tokenSOT, Self.tokenEnglish, Self.tokenTranscribe, Self.tokenNoTimestamps
        ]
        let promptLength = tokens.count
        let features = TensorValue.float32(mel, shape: [1, Self.nMels, Self.nFrames])

        for _ in 0..<Self.maxNewTokens {
            let position = tokens.count - 1
            var inputTokens = tokens
            var runLength = tokens.count
            if let window = staticWindow {
                guard tokens.count <= window else { break }
                // Causal attention: right-padding cannot affect logits at
                // earlier positions, so a static window is safe to pad.
                inputTokens += [Int32](repeating: Self.tokenEOT, count: window - tokens.count)
                runLength = window
            }

            let outputs = try await model.run([
                "input_features": features,
                "decoder_input_ids": .int32(inputTokens, shape: [1, runLength])
            ])
            guard let logits = outputs["logits"] else {
                throw NSError(
                    domain: "Whisper", code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Model returned no logits."]
                )
            }
            let next = Self.argmaxTextToken(logits, position: position)
            if next == Self.tokenEOT { break }
            tokens.append(next)
        }

        return decode(tokens: Array(tokens.dropFirst(promptLength)))
    }

    /// Picks the highest-scoring token at `position`, restricted to text
    /// tokens and <|endoftext|> (timestamps/specials are suppressed).
    private static func argmaxTextToken(_ logits: TensorValue, position: Int) -> Int32 {
        let values = logits.floats()
        let vocab = logits.shape[2]
        let base = position * vocab
        var best = Int(tokenEOT)
        var bestScore = -Float.infinity
        let textLimit = Int(tokenEOT)   // ids below 50257 are text tokens
        for id in 0..<min(vocab, textLimit + 1) {
            let score = values[base + id]
            if score > bestScore {
                bestScore = score
                best = id
            }
        }
        return Int32(best)
    }

    // MARK: - Detokenization (byte-level BPE)

    private func decode(tokens: [Int32]) -> String {
        var mapped = ""
        for token in tokens where token < Self.tokenEOT {
            mapped += vocabulary[Int(token)] ?? ""
        }
        // GPT-2 byte-level decode: each mapped character represents one byte.
        let byteDecoder = Self.byteDecoder
        var bytes: [UInt8] = []
        bytes.reserveCapacity(mapped.count)
        for scalar in mapped.unicodeScalars {
            if let byte = byteDecoder[scalar] { bytes.append(byte) }
        }
        return (String(bytes: bytes, encoding: .utf8) ?? mapped)
            .trimmingCharacters(in: .whitespaces)
    }

    /// Inverse of GPT-2's bytes→unicode mapping.
    private static let byteDecoder: [Unicode.Scalar: UInt8] = {
        var byteToScalar: [UInt8: Unicode.Scalar] = [:]
        var printable: [ClosedRange<UInt8>] = [33...126, 161...172, 174...255]
        var covered = Set<UInt8>()
        for range in printable {
            for byte in range {
                byteToScalar[byte] = Unicode.Scalar(UInt32(byte))!
                covered.insert(byte)
            }
        }
        var offset: UInt32 = 0
        for byte in UInt8.min...UInt8.max where !covered.contains(byte) {
            byteToScalar[byte] = Unicode.Scalar(256 + offset)!
            offset += 1
        }
        var decoder: [Unicode.Scalar: UInt8] = [:]
        for (byte, scalar) in byteToScalar { decoder[scalar] = byte }
        return decoder
    }()

    /// Loads (and caches) Whisper's vocab.json: token string → id, inverted
    /// here to id → token string.
    private static func loadVocabulary() async throws -> [Int: String] {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cacheDir = docs.appendingPathComponent("models/asr")
        try? fm.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let cached = cacheDir.appendingPathComponent("whisper-vocab.json")

        let data: Data
        if fm.fileExists(atPath: cached.path) {
            data = try Data(contentsOf: cached)
        } else {
            guard let url = URL(
                string: "https://huggingface.co/openai/whisper-large-v3-turbo/resolve/main/vocab.json"
            ) else {
                throw NSError(domain: "Whisper", code: 3)
            }
            let (downloaded, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw NSError(
                    domain: "Whisper", code: 4,
                    userInfo: [NSLocalizedDescriptionKey:
                        "Could not download the Whisper tokenizer vocabulary."]
                )
            }
            try downloaded.write(to: cached)
            data = downloaded
        }

        let raw = try JSONDecoder().decode([String: Int].self, from: data)
        var inverted: [Int: String] = [:]
        inverted.reserveCapacity(raw.count)
        for (token, id) in raw { inverted[id] = token }
        return inverted
    }

    // MARK: - Log-Mel spectrogram (Whisper front-end)

    /// Returns `nMels * nFrames` floats in [1, 128, 3000] row-major order.
    private static func logMelSpectrogram(samples input: [Float]) -> [Float] {
        // Pad or trim to exactly 30 s, then reflect-pad n_fft/2 on both sides.
        var audio = input
        if audio.count > chunkSamples {
            audio = Array(audio[0..<chunkSamples])
        } else if audio.count < chunkSamples {
            audio += [Float](repeating: 0, count: chunkSamples - audio.count)
        }
        let pad = nFFT / 2
        var padded = [Float](repeating: 0, count: audio.count + 2 * pad)
        for i in 0..<pad { padded[i] = audio[pad - i] }                       // reflect head
        for i in 0..<audio.count { padded[pad + i] = audio[i] }
        for i in 0..<pad { padded[pad + audio.count + i] = audio[audio.count - 2 - i] }

        // Windowed frames: [nFrames, nFFT] row-major.
        let window = hannWindow(nFFT)
        var frames = [Float](repeating: 0, count: nFrames * nFFT)
        for t in 0..<nFrames {
            let start = t * hopLength
            for n in 0..<nFFT {
                frames[t * nFFT + n] = padded[start + n] * window[n]
            }
        }

        // Power spectrum via DFT-as-matmul: [nFrames, nBins].
        let nBins = nFFT / 2 + 1
        let (cosM, sinM) = dftMatrices(nFFT: nFFT, nBins: nBins)
        var real = [Float](repeating: 0, count: nFrames * nBins)
        var imag = [Float](repeating: 0, count: nFrames * nBins)
        // real = frames [F,N] x cosM^T [N,B]
        cblas_sgemm(
            CblasRowMajor, CblasNoTrans, CblasTrans,
            Int32(nFrames), Int32(nBins), Int32(nFFT),
            1, frames, Int32(nFFT), cosM, Int32(nFFT),
            0, &real, Int32(nBins)
        )
        cblas_sgemm(
            CblasRowMajor, CblasNoTrans, CblasTrans,
            Int32(nFrames), Int32(nBins), Int32(nFFT),
            1, frames, Int32(nFFT), sinM, Int32(nFFT),
            0, &imag, Int32(nBins)
        )
        var power = [Float](repeating: 0, count: nFrames * nBins)
        vDSP.multiply(real, real, result: &power)
        var imagSq = [Float](repeating: 0, count: nFrames * nBins)
        vDSP.multiply(imag, imag, result: &imagSq)
        vDSP.add(power, imagSq, result: &power)

        // Mel projection: mel [F, M] = power [F, B] x filters^T [B, M].
        let filters = melFilterbank(nMels: nMels, nBins: nBins)   // [M, B]
        var mel = [Float](repeating: 0, count: nFrames * nMels)
        cblas_sgemm(
            CblasRowMajor, CblasNoTrans, CblasTrans,
            Int32(nFrames), Int32(nMels), Int32(nBins),
            1, power, Int32(nBins), filters, Int32(nBins),
            0, &mel, Int32(nMels)
        )

        // log10, dynamic-range compression, scaling — transposed to [M, F].
        var logMel = [Float](repeating: 0, count: nMels * nFrames)
        var globalMax = -Float.infinity
        for t in 0..<nFrames {
            for m in 0..<nMels {
                let value = log10(max(mel[t * nMels + m], 1e-10))
                logMel[m * nFrames + t] = value
                if value > globalMax { globalMax = value }
            }
        }
        let floor = globalMax - 8
        for i in 0..<logMel.count {
            logMel[i] = (max(logMel[i], floor) + 4) / 4
        }
        return logMel
    }

    private static func hannWindow(_ n: Int) -> [Float] {
        (0..<n).map { 0.5 * (1 - cos(2 * Float.pi * Float($0) / Float(n))) }
    }

    /// Real DFT basis matrices, each [nBins, nFFT] row-major.
    private static func dftMatrices(nFFT: Int, nBins: Int) -> ([Float], [Float]) {
        var cosM = [Float](repeating: 0, count: nBins * nFFT)
        var sinM = [Float](repeating: 0, count: nBins * nFFT)
        for k in 0..<nBins {
            for n in 0..<nFFT {
                let angle = 2 * Float.pi * Float(k * n) / Float(nFFT)
                cosM[k * nFFT + n] = cos(angle)
                sinM[k * nFFT + n] = -sin(angle)
            }
        }
        return (cosM, sinM)
    }

    /// librosa-compatible Slaney-scale, Slaney-normalized mel filterbank
    /// [nMels, nBins] for sr 16 kHz, fmin 0, fmax 8 kHz.
    private static func melFilterbank(nMels: Int, nBins: Int) -> [Float] {
        let fMax: Float = Float(sampleRate) / 2

        func hzToMel(_ hz: Float) -> Float {
            let fSp: Float = 200.0 / 3
            let minLogHz: Float = 1000
            let minLogMel = minLogHz / fSp
            let logStep = log(Float(6.4)) / 27
            return hz < minLogHz ? hz / fSp : minLogMel + log(hz / minLogHz) / logStep
        }
        func melToHz(_ mel: Float) -> Float {
            let fSp: Float = 200.0 / 3
            let minLogHz: Float = 1000
            let minLogMel = minLogHz / fSp
            let logStep = log(Float(6.4)) / 27
            return mel < minLogMel ? mel * fSp : minLogHz * exp(logStep * (mel - minLogMel))
        }

        let melMin = hzToMel(0)
        let melMax = hzToMel(fMax)
        let melPoints = (0..<(nMels + 2)).map { i in
            melToHz(melMin + (melMax - melMin) * Float(i) / Float(nMels + 1))
        }
        let fftFreqs = (0..<nBins).map { Float($0) * Float(sampleRate) / Float(nFFT) }

        var filters = [Float](repeating: 0, count: nMels * nBins)
        for m in 0..<nMels {
            let lower = melPoints[m]
            let center = melPoints[m + 1]
            let upper = melPoints[m + 2]
            let norm = 2 / (upper - lower)   // Slaney normalization
            for k in 0..<nBins {
                let freq = fftFreqs[k]
                let rising = (freq - lower) / max(center - lower, .ulpOfOne)
                let falling = (upper - freq) / max(upper - center, .ulpOfOne)
                let weight = max(0, min(rising, falling))
                filters[m * nBins + k] = weight * norm
            }
        }
        return filters
    }
}
#endif
