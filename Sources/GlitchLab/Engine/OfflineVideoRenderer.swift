import AVFoundation
import CoreImage
import Foundation

struct RenderRequest {
    let sourceURL: URL
    let outputURL: URL?
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

        let outputURL = try resolvedOutputURL(sourceURL: request.sourceURL, outputURL: request.outputURL)
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        let reader = try AVAssetReader(asset: asset)
        let readerOutput = AVAssetReaderTrackOutput(
            track: videoTrack,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
        )
        readerOutput.alwaysCopiesSampleData = false
        guard reader.canAdd(readerOutput) else {
            throw OfflineVideoRendererError.readerFailed("Cannot add track output.")
        }
        reader.add(readerOutput)

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
        let writerInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 16_000_000
                ]
            ]
        )
        writerInput.expectsMediaDataInRealTime = false
        writerInput.transform = transform

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
        )

        guard writer.canAdd(writerInput) else {
            throw OfflineVideoRendererError.writerFailed("Cannot add writer input.")
        }
        writer.add(writerInput)

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

        while reader.status == .reading {
            try Task.checkCancellation()

            guard let sampleBuffer = readerOutput.copyNextSampleBuffer() else {
                break
            }

            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                continue
            }

            let inputImage = CIImage(cvImageBuffer: imageBuffer)
            let processed = applyEffects(
                to: inputImage,
                request: request,
                zoneMaskImage: zoneMaskImage
            )

            while !writerInput.isReadyForMoreMediaData {
                try Task.checkCancellation()
                try await Task.sleep(nanoseconds: 1_000_000)
            }

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
        }

        writerInput.markAsFinished()

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
        zoneMaskImage: CIImage?
    ) -> CIImage {
        guard
            let effect = request.effects.first(where: { $0.type == .noiseCorruption && $0.isEnabled }),
            let amountParameter = effect.parameters.first(where: { $0.id == "noise" })
        else {
            return image
        }

        let amount = min(max(amountParameter.value, 0), 1)
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

        let noisyImage = noise.applyingFilter(
            "CISourceOverCompositing",
            parameters: [kCIInputBackgroundImageKey: image]
        )

        guard effect.selectedZonesOnly, let zoneMaskImage, !request.selectedZoneIDs.isEmpty else {
            return noisyImage
        }

        return noisyImage.applyingFilter(
            "CIBlendWithMask",
            parameters: [
                kCIInputBackgroundImageKey: image,
                kCIInputMaskImageKey: zoneMaskImage
            ]
        )
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

    private func finishWriting(writer: AVAssetWriter) async throws {
        await writer.finishWriting()
        if writer.status != .completed {
            throw OfflineVideoRendererError.writerFailed(
                writer.error?.localizedDescription ?? "Writer failed."
            )
        }
    }

    private func resolvedOutputURL(sourceURL: URL, outputURL: URL?) throws -> URL {
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
        return rendersDirectory.appendingPathComponent("\(stem)-glitch-\(timestamp).mov")
    }
}
