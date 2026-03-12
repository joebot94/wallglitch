import AVFoundation
import CoreImage
import CoreMedia
import Foundation

struct RenderRequest {
    let sourceURL: URL
    let outputURL: URL?
    let exportProfile: ExportProfile
    let effects: [EffectState]
    let grid: GridConfiguration
    let selectedZoneIDs: Set<Int>
}

enum OfflineVideoRendererError: LocalizedError {
    case missingVideoTrack
    case failedToCreatePixelBuffer
    case cancelled
    case writerFailed(String)
    case readerFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingVideoTrack:
            return "No video track found."
        case .failedToCreatePixelBuffer:
            return "Failed to create output pixel buffer."
        case .cancelled:
            return "Render cancelled."
        case .writerFailed(let reason):
            return "Writer failed: \(reason)"
        case .readerFailed(let reason):
            return "Reader failed: \(reason)"
        }
    }
}

actor OfflineVideoRenderer {
    private let ciContext = CIContext()

    func render(
        request: RenderRequest,
        onProgress: @Sendable @escaping (Double) async -> Void
    ) async throws -> URL {
        let asset = AVURLAsset(url: request.sourceURL)
        let duration = try await asset.load(.duration)
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw OfflineVideoRendererError.missingVideoTrack
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        let transform = try await videoTrack.load(.preferredTransform)
        let width = max(Int(naturalSize.width.rounded()), 1)
        let height = max(Int(naturalSize.height.rounded()), 1)
        let durationSeconds = max(CMTimeGetSeconds(duration), 0.001)

        let outputURL = try resolvedOutputURL(
            sourceURL: request.sourceURL,
            outputURL: request.outputURL,
            exportProfile: request.exportProfile
        )
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        let reader = try AVAssetReader(asset: asset)
        let videoReaderOutput = AVAssetReaderTrackOutput(
            track: videoTrack,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
        )
        videoReaderOutput.alwaysCopiesSampleData = false
        guard reader.canAdd(videoReaderOutput) else {
            throw OfflineVideoRendererError.readerFailed("Cannot add track output.")
        }
        reader.add(videoReaderOutput)

        let audioTrack = try await asset.loadTracks(withMediaType: .audio).first
        var audioReaderOutput: AVAssetReaderTrackOutput?
        if let audioTrack {
            let candidate = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
            candidate.alwaysCopiesSampleData = false
            guard reader.canAdd(candidate) else {
                throw OfflineVideoRendererError.readerFailed("Cannot add audio track output.")
            }
            reader.add(candidate)
            audioReaderOutput = candidate
        }

        let writerConfig = makeWriterVideoConfig(
            profile: request.exportProfile,
            width: width,
            height: height
        )
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: writerConfig.fileType)
        let videoWriterInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: writerConfig.outputSettings
        )
        videoWriterInput.expectsMediaDataInRealTime = false
        videoWriterInput.transform = transform

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoWriterInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
        )

        guard writer.canAdd(videoWriterInput) else {
            throw OfflineVideoRendererError.writerFailed("Cannot add writer input.")
        }
        writer.add(videoWriterInput)

        var audioWriterInput: AVAssetWriterInput?
        if let audioTrack {
            let formatDescriptions = try await audioTrack.load(.formatDescriptions)
            let sourceFormatHint = formatDescriptions.first
            let candidate = AVAssetWriterInput(
                mediaType: .audio,
                outputSettings: nil,
                sourceFormatHint: sourceFormatHint
            )
            candidate.expectsMediaDataInRealTime = false
            guard writer.canAdd(candidate) else {
                throw OfflineVideoRendererError.writerFailed("Cannot add audio writer input.")
            }
            writer.add(candidate)
            audioWriterInput = candidate
        }

        guard reader.startReading() else {
            throw OfflineVideoRendererError.readerFailed(reader.error?.localizedDescription ?? "Unknown reader error")
        }
        guard writer.startWriting() else {
            throw OfflineVideoRendererError.writerFailed(writer.error?.localizedDescription ?? "Unknown writer error")
        }
        writer.startSession(atSourceTime: .zero)

        let zoneMaskImage = makeZoneMaskImage(
            size: CGSize(width: width, height: height),
            grid: request.grid,
            selectedZoneIDs: request.selectedZoneIDs
        )
        var audioFinished = (audioReaderOutput == nil || audioWriterInput == nil)

        while reader.status == .reading {
            try Task.checkCancellation()

            guard let sampleBuffer = videoReaderOutput.copyNextSampleBuffer() else {
                break
            }

            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                continue
            }

            let inputImage = CIImage(cvImageBuffer: imageBuffer)
            let frameTimeSeconds = CMTimeGetSeconds(presentationTime)
            let processed = applyEffects(
                to: inputImage,
                request: request,
                zoneMaskImage: zoneMaskImage,
                frameTimeSeconds: frameTimeSeconds.isFinite ? frameTimeSeconds : 0
            )

            try await waitUntilReadyForMoreMediaData(
                input: videoWriterInput,
                writer: writer,
                reader: reader
            )

            guard
                let pool = adaptor.pixelBufferPool,
                let outputBuffer = makePixelBuffer(from: pool)
            else {
                throw OfflineVideoRendererError.failedToCreatePixelBuffer
            }

            ciContext.render(processed, to: outputBuffer)
            if !adaptor.append(outputBuffer, withPresentationTime: presentationTime) {
                throw OfflineVideoRendererError.writerFailed(
                    writer.error?.localizedDescription ?? "Failed appending frame."
                )
            }

            let seconds = CMTimeGetSeconds(presentationTime)
            let progress = min(max(seconds / durationSeconds, 0), 1)
            await onProgress(progress)

            if
                !audioFinished,
                let audioReaderOutput,
                let audioWriterInput
            {
                audioFinished = try appendAvailableAudioSamples(
                    output: audioReaderOutput,
                    input: audioWriterInput,
                    writer: writer,
                    maxSamples: 32
                )
            }
        }

        videoWriterInput.markAsFinished()

        if
            let audioReaderOutput,
            let audioWriterInput
        {
            while !audioFinished {
                try Task.checkCancellation()

                try await waitUntilReadyForMoreMediaData(
                    input: audioWriterInput,
                    writer: writer,
                    reader: reader
                )

                audioFinished = try appendAvailableAudioSamples(
                    output: audioReaderOutput,
                    input: audioWriterInput,
                    writer: writer,
                    maxSamples: 256
                )
            }
        }

        if Task.isCancelled {
            reader.cancelReading()
            writer.cancelWriting()
            try? FileManager.default.removeItem(at: outputURL)
            throw OfflineVideoRendererError.cancelled
        }

        if reader.status == .failed {
            throw OfflineVideoRendererError.readerFailed(
                reader.error?.localizedDescription ?? "Reader failed."
            )
        }

        try await finishWriting(writer: writer)
        await onProgress(1.0)
        return outputURL
    }

    private func applyEffects(
        to image: CIImage,
        request: RenderRequest,
        zoneMaskImage: CIImage?,
        frameTimeSeconds: Double
    ) -> CIImage {
        var currentImage = image
        for effect in request.effects where effect.isEnabled {
            switch effect.type {
            case .rgbShift:
                currentImage = applyMaskedEffect(
                    baseImage: currentImage,
                    effect: effect,
                    selectedZoneIDs: request.selectedZoneIDs,
                    zoneMaskImage: zoneMaskImage
                ) { baseImage in
                    applyRGBShift(to: baseImage, effect: effect)
                }
            case .screenTear:
                currentImage = applyMaskedEffect(
                    baseImage: currentImage,
                    effect: effect,
                    selectedZoneIDs: request.selectedZoneIDs,
                    zoneMaskImage: zoneMaskImage
                ) { baseImage in
                    applyScreenTear(to: baseImage, effect: effect)
                }
            case .pixelDrift:
                currentImage = applyMaskedEffect(
                    baseImage: currentImage,
                    effect: effect,
                    selectedZoneIDs: request.selectedZoneIDs,
                    zoneMaskImage: zoneMaskImage
                ) { baseImage in
                    applyPixelDrift(to: baseImage, effect: effect)
                }
            case .blockScramble:
                currentImage = applyMaskedEffect(
                    baseImage: currentImage,
                    effect: effect,
                    selectedZoneIDs: request.selectedZoneIDs,
                    zoneMaskImage: zoneMaskImage
                ) { baseImage in
                    applyBlockScramble(to: baseImage, effect: effect)
                }
            case .zoneSwap:
                currentImage = applyZoneSwap(
                    to: currentImage,
                    effect: effect,
                    grid: request.grid,
                    selectedZoneIDs: request.selectedZoneIDs,
                    frameTimeSeconds: frameTimeSeconds
                )
            case .noiseCorruption:
                currentImage = applyMaskedEffect(
                    baseImage: currentImage,
                    effect: effect,
                    selectedZoneIDs: request.selectedZoneIDs,
                    zoneMaskImage: zoneMaskImage
                ) { baseImage in
                    applyNoiseCorruption(to: baseImage, effect: effect)
                }
            case .temporalHold:
                continue
            }
        }
        return currentImage
    }

    private func applyMaskedEffect(
        baseImage: CIImage,
        effect: EffectState,
        selectedZoneIDs: Set<Int>,
        zoneMaskImage: CIImage?,
        transform: (CIImage) -> CIImage
    ) -> CIImage {
        let transformed = transform(baseImage).cropped(to: baseImage.extent)
        guard
            effect.selectedZonesOnly,
            !selectedZoneIDs.isEmpty,
            let zoneMaskImage
        else {
            return transformed
        }
        return transformed.applyingFilter(
            "CIBlendWithMask",
            parameters: [
                kCIInputBackgroundImageKey: baseImage,
                kCIInputMaskImageKey: zoneMaskImage
            ]
        )
    }

    private func applyNoiseCorruption(to image: CIImage, effect: EffectState) -> CIImage {
        let amount = min(max(parameterValue(in: effect, id: "noise", defaultValue: 0), 0), 1)
        if amount <= 0 {
            return image
        }

        let noise = CIFilter(name: "CIRandomGenerator")?.outputImage?
            .cropped(to: image.extent)
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
            .applyingFilter(
                "CIColorMatrix",
                parameters: [
                    "inputRVector": CIVector(x: amount, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: amount, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: amount, w: 0),
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: amount)
                ]
            )

        guard let noise else { return image }

        return noise.applyingFilter(
            "CISourceOverCompositing",
            parameters: [kCIInputBackgroundImageKey: image]
        )
    }

    private func applyRGBShift(to image: CIImage, effect: EffectState) -> CIImage {
        let amount = min(max(parameterValue(in: effect, id: "amount", defaultValue: 0), 0), 1)
        if amount <= 0 { return image }

        let angle = parameterValue(in: effect, id: "angle", defaultValue: 0) * .pi / 180
        let distance = amount * 30
        let dx = cos(angle) * distance
        let dy = sin(angle) * distance

        let red = isolateChannel(
            image.transformed(by: CGAffineTransform(translationX: dx, y: dy)),
            red: 1,
            green: 0,
            blue: 0
        )
        let green = isolateChannel(
            image.transformed(by: CGAffineTransform(translationX: -dx * 0.7, y: -dy * 0.7)),
            red: 0,
            green: 1,
            blue: 0
        )
        let blue = isolateChannel(
            image.transformed(by: CGAffineTransform(translationX: -dy * 0.4, y: dx * 0.4)),
            red: 0,
            green: 0,
            blue: 1
        )

        return red
            .applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: green])
            .applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: blue])
            .cropped(to: image.extent)
    }

    private func applyScreenTear(to image: CIImage, effect: EffectState) -> CIImage {
        let intensity = min(max(parameterValue(in: effect, id: "intensity", defaultValue: 0), 0), 1)
        if intensity <= 0 { return image }

        let lineCount = max(parameterValue(in: effect, id: "line_count", defaultValue: 8), 1)
        let pixelScale = max(2, image.extent.height / lineCount)

        let displacementMap = CIFilter(name: "CIRandomGenerator")?.outputImage?
            .cropped(to: image.extent)
            .applyingFilter(
                "CIColorControls",
                parameters: [
                    kCIInputSaturationKey: 0,
                    kCIInputContrastKey: 1 + (intensity * 2.2)
                ]
            )
            .applyingFilter(
                "CIPixellate",
                parameters: [
                    kCIInputScaleKey: pixelScale,
                    kCIInputCenterKey: CIVector(x: image.extent.midX, y: image.extent.midY)
                ]
            )
            .cropped(to: image.extent)

        guard let displacementMap else { return image }

        return image.applyingFilter(
            "CIDisplacementDistortion",
            parameters: [
                "inputDisplacementImage": displacementMap,
                kCIInputScaleKey: intensity * 36
            ]
        )
    }

    private func applyPixelDrift(to image: CIImage, effect: EffectState) -> CIImage {
        let drift = min(max(parameterValue(in: effect, id: "drift", defaultValue: 0), 0), 1)
        if drift <= 0 { return image }

        let blockSize = max(parameterValue(in: effect, id: "block_size", defaultValue: 8), 1)
        let pixelated = image.applyingFilter(
            "CIPixellate",
            parameters: [
                kCIInputScaleKey: blockSize,
                kCIInputCenterKey: CIVector(x: image.extent.midX, y: image.extent.midY)
            ]
        )

        let shifted = pixelated.transformed(by: CGAffineTransform(
            translationX: drift * 24,
            y: drift * 10
        ))
        let alpha = min(0.9, 0.2 + (drift * 0.6))
        let driftLayer = shifted.applyingFilter(
            "CIColorMatrix",
            parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: alpha)
            ]
        )
        return driftLayer.applyingFilter(
            "CISourceOverCompositing",
            parameters: [kCIInputBackgroundImageKey: image]
        )
    }

    private func applyBlockScramble(to image: CIImage, effect: EffectState) -> CIImage {
        let amount = min(max(parameterValue(in: effect, id: "amount", defaultValue: 0), 0), 1)
        if amount <= 0 { return image }

        // Cap iteration workload for predictable performance on long/4K clips.
        let requestedIterations = Int(parameterValue(in: effect, id: "iterations", defaultValue: 3).rounded())
        let iterations = min(max(requestedIterations, 1), 8)

        let extent = image.extent
        let minDimension = max(1.0, min(extent.width, extent.height))
        let baseBlockScale = max(6.0, minDimension / (8.0 + (amount * 30.0)))

        var output = image
        for index in 0..<iterations {
            let seed = Double(index + 1) * 41.37
            let mapScale = baseBlockScale + (Double(index) * 0.5)

            let displacementMap = CIFilter(name: "CIRandomGenerator")?.outputImage?
                .transformed(by: CGAffineTransform(translationX: seed * 0.73, y: seed * 1.11))
                .cropped(to: extent)
                .applyingFilter(
                    "CIPixellate",
                    parameters: [
                        kCIInputScaleKey: mapScale,
                        kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY)
                    ]
                )
                .applyingFilter(
                    "CIColorControls",
                    parameters: [
                        kCIInputSaturationKey: 0,
                        kCIInputContrastKey: 1.8
                    ]
                )
                .cropped(to: extent)

            guard let displacementMap else { continue }

            let passStrength = amount * (mapScale * (0.45 + (Double(index) / Double(max(iterations, 1)))))
            output = output.applyingFilter(
                "CIDisplacementDistortion",
                parameters: [
                    "inputDisplacementImage": displacementMap,
                    kCIInputScaleKey: passStrength
                ]
            )
            .cropped(to: extent)
        }

        return output
    }

    private func applyZoneSwap(
        to image: CIImage,
        effect: EffectState,
        grid: GridConfiguration,
        selectedZoneIDs: Set<Int>,
        frameTimeSeconds: Double
    ) -> CIImage {
        let swapRate = min(max(parameterValue(in: effect, id: "swap_rate", defaultValue: 0), 0), 1)
        if swapRate <= 0 { return image }
        let changeRate = min(max(parameterValue(in: effect, id: "change_rate", defaultValue: 8), 0.25), 60)

        let zonePool: [Int]
        if effect.selectedZonesOnly, !selectedZoneIDs.isEmpty {
            zonePool = selectedZoneIDs.sorted()
        } else {
            zonePool = Array(1...max(grid.zoneCount, 0))
        }

        if zonePool.count < 2 {
            return image
        }

        let requestedPairs = Int(parameterValue(in: effect, id: "pair_count", defaultValue: 4).rounded())
        let maxPairCapacity = min(zonePool.count / 2, 24)
        let cappedPairs = min(max(requestedPairs, 1), maxPairCapacity)
        let activePairs = min(
            max(1, Int((Double(cappedPairs) * max(swapRate, 0.08)).rounded())),
            cappedPairs
        )

        var generator = SeededGenerator(
            seed: seedForZoneSwap(
                frameTimeSeconds: frameTimeSeconds,
                changeRate: changeRate,
                grid: grid
            )
        )
        var shuffledPool = zonePool
        shuffle(&shuffledPool, using: &generator)

        let source = image
        var output = image
        for index in 0..<activePairs {
            let firstID = shuffledPool[index * 2]
            let secondID = shuffledPool[(index * 2) + 1]

            guard
                let firstRect = rectForZone(id: firstID, grid: grid, extent: source.extent),
                let secondRect = rectForZone(id: secondID, grid: grid, extent: source.extent)
            else {
                continue
            }

            let firstTile = source
                .cropped(to: firstRect)
                .transformed(
                    by: CGAffineTransform(
                        translationX: secondRect.origin.x - firstRect.origin.x,
                        y: secondRect.origin.y - firstRect.origin.y
                    )
                )
            let secondTile = source
                .cropped(to: secondRect)
                .transformed(
                    by: CGAffineTransform(
                        translationX: firstRect.origin.x - secondRect.origin.x,
                        y: firstRect.origin.y - secondRect.origin.y
                    )
                )

            output = firstTile.composited(over: output)
            output = secondTile.composited(over: output)
        }

        return output.cropped(to: source.extent)
    }

    private func isolateChannel(
        _ image: CIImage,
        red: Double,
        green: Double,
        blue: Double
    ) -> CIImage {
        image.applyingFilter(
            "CIColorMatrix",
            parameters: [
                "inputRVector": CIVector(x: red, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: green, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: blue, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
            ]
        )
    }

    private func parameterValue(
        in effect: EffectState,
        id: String,
        defaultValue: Double
    ) -> Double {
        effect.parameters.first(where: { $0.id == id })?.value ?? defaultValue
    }

    private func rectForZone(
        id: Int,
        grid: GridConfiguration,
        extent: CGRect
    ) -> CGRect? {
        let cols = max(grid.cols, 1)
        let rows = max(grid.rows, 1)
        guard id >= 1, id <= cols * rows else { return nil }

        let rowFromTop = (id - 1) / cols
        let col = (id - 1) % cols
        let flippedRow = (rows - 1) - rowFromTop

        let cellWidth = extent.width / CGFloat(cols)
        let cellHeight = extent.height / CGFloat(rows)

        let rect = CGRect(
            x: extent.origin.x + (CGFloat(col) * cellWidth),
            y: extent.origin.y + (CGFloat(flippedRow) * cellHeight),
            width: ceil(cellWidth),
            height: ceil(cellHeight)
        ).intersection(extent)

        return rect.isNull || rect.isEmpty ? nil : rect
    }

    private func seedForZoneSwap(
        frameTimeSeconds: Double,
        changeRate: Double,
        grid: GridConfiguration
    ) -> UInt64 {
        let frameBucket = UInt64(max((frameTimeSeconds * changeRate).rounded(), 0))
        let gridSeed = UInt64((grid.rows * 131) ^ (grid.cols * 977))
        return frameBucket &* 1_315_423_911 ^ gridSeed &+ 0x9E3779B97F4A7C15
    }

    private func shuffle(_ array: inout [Int], using generator: inout SeededGenerator) {
        guard array.count > 1 else { return }
        var index = array.count - 1
        while index > 0 {
            let swapIndex = generator.nextInt(upperBound: index + 1)
            if swapIndex != index {
                array.swapAt(index, swapIndex)
            }
            index -= 1
        }
    }

    private struct SeededGenerator {
        private var state: UInt64

        init(seed: UInt64) {
            self.state = seed == 0 ? 0xD1B54A32D192ED03 : seed
        }

        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }

        mutating func nextInt(upperBound: Int) -> Int {
            guard upperBound > 1 else { return 0 }
            return Int(next() % UInt64(upperBound))
        }
    }

    private func makeZoneMaskImage(
        size: CGSize,
        grid: GridConfiguration,
        selectedZoneIDs: Set<Int>
    ) -> CIImage? {
        guard !selectedZoneIDs.isEmpty else { return nil }
        let width = max(Int(size.width), 1)
        let height = max(Int(size.height), 1)

        guard
            let colorSpace = CGColorSpace(name: CGColorSpace.linearGray),
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            )
        else {
            return nil
        }

        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let cellWidth = CGFloat(width) / CGFloat(max(grid.cols, 1))
        let cellHeight = CGFloat(height) / CGFloat(max(grid.rows, 1))

        context.setFillColor(gray: 1, alpha: 1)
        for zoneID in selectedZoneIDs {
            let row = (zoneID - 1) / max(grid.cols, 1)
            let col = (zoneID - 1) % max(grid.cols, 1)
            guard row >= 0, row < grid.rows, col >= 0, col < grid.cols else { continue }

            let flippedRow = (grid.rows - 1) - row
            let rect = CGRect(
                x: CGFloat(col) * cellWidth,
                y: CGFloat(flippedRow) * cellHeight,
                width: ceil(cellWidth),
                height: ceil(cellHeight)
            )
            context.fill(rect)
        }

        guard let cgImage = context.makeImage() else { return nil }
        return CIImage(cgImage: cgImage)
    }

    private func makePixelBuffer(from pool: CVPixelBufferPool) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
        return pixelBuffer
    }

    private func waitUntilReadyForMoreMediaData(
        input: AVAssetWriterInput,
        writer: AVAssetWriter,
        reader: AVAssetReader
    ) async throws {
        let waitStart = Date()
        while !input.isReadyForMoreMediaData {
            try Task.checkCancellation()

            if writer.status == .failed {
                throw OfflineVideoRendererError.writerFailed(
                    writer.error?.localizedDescription ?? "Writer failed while waiting for input readiness."
                )
            }
            if writer.status == .cancelled {
                throw OfflineVideoRendererError.cancelled
            }
            if reader.status == .failed {
                throw OfflineVideoRendererError.readerFailed(
                    reader.error?.localizedDescription ?? "Reader failed while waiting for writer readiness."
                )
            }
            if Date().timeIntervalSince(waitStart) > 15 {
                throw OfflineVideoRendererError.writerFailed(
                    "Timed out waiting for writer input readiness."
                )
            }

            try await Task.sleep(nanoseconds: 1_000_000)
        }
    }

    private func appendAvailableAudioSamples(
        output: AVAssetReaderTrackOutput,
        input: AVAssetWriterInput,
        writer: AVAssetWriter,
        maxSamples: Int
    ) throws -> Bool {
        var appended = 0
        while input.isReadyForMoreMediaData && appended < maxSamples {
            guard let audioSampleBuffer = output.copyNextSampleBuffer() else {
                input.markAsFinished()
                return true
            }

            if !input.append(audioSampleBuffer) {
                throw OfflineVideoRendererError.writerFailed(
                    writer.error?.localizedDescription ?? "Failed appending audio sample."
                )
            }
            appended += 1
        }
        return false
    }

    private func finishWriting(writer: AVAssetWriter) async throws {
        await writer.finishWriting()
        if writer.status != .completed {
            throw OfflineVideoRendererError.writerFailed(
                writer.error?.localizedDescription ?? "Writer failed."
            )
        }
    }

    private func makeWriterVideoConfig(
        profile: ExportProfile,
        width: Int,
        height: Int
    ) -> (fileType: AVFileType, outputSettings: [String: Any]) {
        let codec: AVVideoCodecType
        let averageBitRate: Int?

        switch profile {
        case .h264:
            codec = .h264
            averageBitRate = 16_000_000
        case .hevc:
            codec = .hevc
            averageBitRate = 14_000_000
        case .proRes422:
            codec = .proRes422
            averageBitRate = nil
        case .proRes422HQ:
            codec = .proRes422HQ
            averageBitRate = nil
        }

        var outputSettings: [String: Any] = [
            AVVideoCodecKey: codec,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]
        if let averageBitRate {
            outputSettings[AVVideoCompressionPropertiesKey] = [
                AVVideoAverageBitRateKey: averageBitRate
            ]
        }

        return (.mov, outputSettings)
    }

    private func resolvedOutputURL(
        sourceURL: URL,
        outputURL: URL?,
        exportProfile: ExportProfile
    ) throws -> URL {
        if let outputURL {
            return outputURL
        }

        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
        let rendersDirectory = documentsDirectory.appendingPathComponent("GlitchLabRenders", isDirectory: true)
        try FileManager.default.createDirectory(at: rendersDirectory, withIntermediateDirectories: true)

        let timestamp = ISO8601DateFormatter()
            .string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let stem = sourceURL.deletingPathExtension().lastPathComponent
        return rendersDirectory.appendingPathComponent(
            "\(stem)-glitch-\(exportProfile.commandName)-\(timestamp).mov"
        )
    }
}
