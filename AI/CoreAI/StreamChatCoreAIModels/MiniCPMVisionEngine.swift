#if canImport(CoreAI) && os(iOS)
// MiniCPMVisionEngine.swift
// MiniCPM-V 4.6 vision-language inference on the Core AI pipelined engine.
//
// Ported from the coreai-model-zoo reference host (BSD-3-Clause,
// https://github.com/john-rocky/coreai-model-zoo,
// apps/MiniCPMVisualIntel/Sources/MiniCPMVLBackend.swift).
//
// Two bundles, installed by ModelDownloader under Documents/models/vlm/:
//   * minicpmv46_vlm_decode_int8hu — decoder LanguageBundle
//     (input_ids → logits + a static `image_embeds`[64,1024] f16 buffer;
//     in-graph gather: embed = ids < V ? embed_tokens[ids] : image_embeds[ids−V]).
//   * minicpmv46_vision_int8lin — fixed-grid SigLIP `.aimodel`, run once per
//     image: pixel_values[1,3,448,448] f16 → image_features[64,1024].
//
// Host contract (mirrors the gated python pipeline):
//   * preprocess: resize 448x448, normalize x/127.5−1, CHW [1,3,448,448].
//   * prompt: ChatML; 64 × <|image_pad|> inline in the user turn, rewritten
//     to extension ids V+slot so the graph gathers from `image_embeds`.

import CoreAI
import CoreAILanguageModels
import CoreAIShared
import CoreGraphics
import Foundation
import Metal
import Tokenizers

@MainActor
final class MiniCPMVisionEngine {
    private let vocabularySize: Int32 = 248_094
    private let imagePadToken: Int32 = 248_056
    private let visionTokens = 64        // merged vision tokens (8x8 @ 448px)
    private let hiddenSize = 1024
    private let imageSide = 448

    private var engine: (any InferenceEngine)?
    private var tokenizer: Tokenizer?
    private var visionModel: AIModel?
    private var visionFunction: InferenceFunction?
    private var visionDescriptor: InferenceFunctionDescriptor?
    private var imageBuffer: MTLBuffer?
    private var contextLength = 4096
    private var eosTokenID = 248_044

    var isLoaded: Bool { engine != nil }

    /// Loads the decoder + vision bundles for `model` (must be installed).
    func load(model: VisionLanguageModel) async throws {
        guard let decoderURL = model.decoderBundleURL,
              let visionURL = model.visionModelURL else {
            throw Self.error("\(model.displayName) is not installed. Get it from the AI model settings.")
        }
        if getenv("COREAI_CHUNK_THRESHOLD") == nil {
            setenv("COREAI_CHUNK_THRESHOLD", "1", 1)
        }

        let bundle = try LanguageBundle(at: decoderURL)
        contextLength = bundle.maxContextLength

        guard let device = MTLCreateSystemDefaultDevice() else {
            throw Self.error("No Metal device is available.")
        }
        let buffer = device.makeBuffer(
            length: visionTokens * hiddenSize * 2,
            options: .storageModeShared
        )!
        memset(buffer.contents(), 0, buffer.length)
        imageBuffer = buffer

        let config = ModelConfig(
            name: bundle.name,
            tokenizer: bundle.tokenizer,
            vocabSize: bundle.vocabSize,
            maxContextLength: bundle.maxContextLength,
            serializedModel: [bundle.modelAssetPath],
            function: bundle.language.functionMap?.name(for: "main") ?? "main"
        )
        engine = try await EngineFactory.createEngine(
            config: try JSONEncoder().encode(config),
            modelURL: try bundle.requireModelURL(for: ModelBundle.ComponentKey.main),
            options: EngineOptions(staticInputBuffers: [
                "image_embeds": StaticInputBuffer(buffer)
            ])
        )
        let tok = try await bundle.loadTokenizer()
        tokenizer = tok
        if let eos = tok.eosTokenId { eosTokenID = eos }

        var options = SpecializationOptions(preferredComputeUnitKind: .gpu)
        options.expectFrequentReshapes = false
        let vision = try await AIModel(contentsOf: visionURL, options: options)
        guard let function = try vision.loadFunction(named: "main") else {
            throw Self.error("MiniCPM vision main function is unavailable.")
        }
        visionModel = vision
        visionFunction = function
        visionDescriptor = function.descriptor

        // Warm both graphs now so the first real photo answers immediately:
        // one decode step compiles the LLM, a dummy encode compiles SigLIP
        // (its cold MPSGraph→Metal compile is ~2.7 s otherwise).
        _ = try await run(ids: [9707], maxTokens: 1, onText: { _ in })
        try? await encode(pixels: [Float16](repeating: 0, count: 3 * imageSide * imageSide))
    }

    func unload() {
        engine = nil
        tokenizer = nil
        visionFunction = nil
        visionModel = nil
        visionDescriptor = nil
        imageBuffer = nil
    }

    // MARK: - Image attach (preprocess + vision encode → static buffer)

    /// Preprocess + vision-encode a photo into the static image buffer.
    /// One image serves the whole generation (each call re-prefills).
    func attach(cgImage: CGImage) async throws {
        guard let imageBuffer else { throw Self.error("MiniCPM is not loaded.") }
        let embeds = try await encode(pixels: Self.preprocess(cgImage: cgImage, side: imageSide))
        let pointer = imageBuffer.contents().assumingMemoryBound(to: Float16.self)
        for index in 0..<min(embeds.count, visionTokens * hiddenSize) {
            pointer[index] = Float16(embeds[index])
        }
    }

    @discardableResult
    private func encode(pixels: [Float16]) async throws -> [Float] {
        guard let visionFunction, let visionDescriptor else {
            throw Self.error("MiniCPM vision encoder is not loaded.")
        }
        guard case .ndArray(let pixelsIn)? = visionDescriptor.inputDescriptor(of: "pixel_values") else {
            throw Self.error("MiniCPM vision pixel_values input is missing.")
        }
        var pixelArray = NDArray(
            descriptor: pixelsIn.resolvingDynamicDimensions([1, 3, imageSide, imageSide])
        )
        fillNDArray(&pixelArray, as: Float16.self, with: pixels)

        guard case .ndArray(let featuresOut)? = visionDescriptor.outputDescriptor(of: "image_features") else {
            throw Self.error("MiniCPM vision image_features output is missing.")
        }
        var featuresArray = NDArray(
            descriptor: featuresOut.resolvingDynamicDimensions([visionTokens, hiddenSize])
        )
        var outputs = InferenceFunction.MutableViews()
        outputs.insert(&featuresArray, for: "image_features")

        _ = try await visionFunction.run(
            inputs: ["pixel_values": pixelArray],
            states: InferenceFunction.MutableViews(),
            outputViews: consume outputs
        )
        return flattenAsFloat(featuresArray)
    }

    // MARK: - Generate

    /// Streams an answer about the attached image. `onUpdate` receives the
    /// full decoded text after each new token.
    func generate(
        question: String,
        maxNewTokens: Int = 512,
        onUpdate: @escaping (String) -> Void
    ) async throws {
        guard let tokenizer else { throw Self.error("MiniCPM is not loaded.") }
        let text = "<|im_start|>user\n"
            + String(repeating: "<|image_pad|>", count: visionTokens)
            + "\n\(question)<|im_end|>\n<|im_start|>assistant\n"
        var ids = tokenizer.encode(text: text).map { Int32($0) }
        var slot: Int32 = 0
        for index in ids.indices where ids[index] == imagePadToken {
            ids[index] = vocabularySize + slot
            slot += 1
        }
        guard slot == Int32(visionTokens) else {
            throw Self.error("Expected \(visionTokens) image pads, found \(slot).")
        }
        guard ids.count < contextLength - 1 else {
            throw Self.error("The question is too long for MiniCPM's context.")
        }
        let budget = min(maxNewTokens, contextLength - ids.count - 1)
        _ = try await run(ids: ids, maxTokens: budget) { generated in
            onUpdate(tokenizer.decode(tokens: generated, skipSpecialTokens: true))
        }
    }

    @discardableResult
    private func run(
        ids: [Int32],
        maxTokens: Int,
        onText: ([Int]) -> Void
    ) async throws -> Int {
        guard let engine else { throw Self.error("MiniCPM engine is not loaded.") }
        try await engine.reset()
        let stream = try engine.generate(
            with: ids,
            samplingConfiguration: SamplingConfiguration(temperature: 0),
            inferenceOptions: InferenceOptions(maxTokens: maxTokens)
        )
        var generated: [Int] = []
        for try await step in stream {
            let token = Int(step.tokenId)
            if token == eosTokenID { break }
            generated.append(token)
            onText(generated)
            try Task.checkCancellation()
        }
        return generated.count
    }

    // MARK: - Preprocess (resize 448 + x/127.5−1, CHW [1,3,448,448])

    nonisolated static func preprocess(cgImage: CGImage, side: Int) -> [Float16] {
        var rgba = [UInt8](repeating: 0, count: side * side * 4)
        let context = CGContext(
            data: &rgba,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))

        var output = [Float16](repeating: 0, count: 3 * side * side)
        for channel in 0..<3 {
            let channelBase = channel * side * side
            for y in 0..<side {
                for x in 0..<side {
                    let value = Float(rgba[(y * side + x) * 4 + channel]) / 127.5 - 1.0
                    output[channelBase + y * side + x] = Float16(value)
                }
            }
        }
        return output
    }

    private static func error(_ message: String) -> Error {
        NSError(domain: "MiniCPMVision", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
#endif
