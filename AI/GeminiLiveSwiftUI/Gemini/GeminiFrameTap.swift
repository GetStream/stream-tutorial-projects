import CoreImage
import Foundation
import ImageIO
import os
import StreamVideo
import UniformTypeIdentifiers

/// A pass-through Stream Video `VideoFilter` that samples the camera feed at
/// ~1 fps, rotates each frame upright, downscales it and emits a JPEG for the
/// Gemini Live API. The frame returned to Stream is untouched, so the on-screen
/// preview and the call video are unaffected.
nonisolated final class GeminiFrameTap: @unchecked Sendable {
    /// Called off the main thread with JPEG bytes.
    var onFrame: (@Sendable (Data) -> Void)? {
        get { lock.withLock { $0.onFrame } }
        set { lock.withLock { $0.onFrame = newValue } }
    }

    var isEnabled: Bool {
        get { lock.withLock { $0.isEnabled } }
        set { lock.withLock { $0.isEnabled = newValue } }
    }

    private(set) var filter: VideoFilter!

    private struct State {
        var onFrame: (@Sendable (Data) -> Void)?
        var isEnabled = true
        var lastSent: TimeInterval = 0
    }

    private let lock = OSAllocatedUnfairLock(initialState: State())
    private let context = CIContext(options: [.useSoftwareRenderer: false])
    private let logger = Logger(subsystem: "io.getstream.streamlive", category: "FrameTap")
    private let interval: TimeInterval
    private let maxDimension: CGFloat
    private let quality: CGFloat

    init(
        interval: TimeInterval = StreamLiveConfig.frameInterval,
        maxDimension: CGFloat = StreamLiveConfig.frameMaxDimension,
        quality: CGFloat = StreamLiveConfig.frameJPEGQuality
    ) {
        self.interval = interval
        self.maxDimension = maxDimension
        self.quality = quality
        filter = VideoFilter(id: "gemini-frame-tap", name: "Gemini") { [weak self] input in
            self?.sample(input)
            return input.originalImage
        }
    }

    private func sample(_ input: VideoFilter.Input) {
        let now = CFAbsoluteTimeGetCurrent()
        let (callback, due) = lock.withLock { state -> ((@Sendable (Data) -> Void)?, Bool) in
            guard state.isEnabled, let cb = state.onFrame, now - state.lastSent >= interval else { return (nil, false) }
            state.lastSent = now
            return (cb, true)
        }
        guard due, let callback else { return }

        // Frames arrive in sensor orientation; the SDK's orientation hint maps
        // upright -> sensor, so apply its inverse to get an upright picture.
        var image = input.originalImage.oriented(Self.inverse(of: input.originalImageOrientation))
        let extent = image.extent
        let scale = min(1, maxDimension / max(extent.width, extent.height))
        if scale < 1 {
            image = image.transformed(by: .init(scaleX: scale, y: scale))
        }

        guard let cgImage = context.createCGImage(image, from: image.extent) else { return }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(destination, cgImage, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return }
        callback(data as Data)
    }

    private static func inverse(of orientation: CGImagePropertyOrientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .left: .right
        case .right: .left
        case .leftMirrored: .rightMirrored
        case .rightMirrored: .leftMirrored
        default: orientation
        }
    }
}
