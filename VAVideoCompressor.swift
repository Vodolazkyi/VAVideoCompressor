//
//  VAVideoCompressor.swift
//  VAVideoCompressor
//
//  Created by Anton Vodolazkyi on 29.07.2018.
//  Copyright © 2018 Anton Vodolazkyi. All rights reserved.
//

import AVFoundation

public enum VAVideoConversionPreset {
    case `default`
    case veryLow
    case low
    case medium
    case high
    case veryHigh
}

public enum VAVideoConverterError: Error {
    case emptyTracks
    case fileAlreadyExist
    case failed
}

final class VAVideoCompressor {
    
    public static func exportAsynchronously(
        with asset: AVAsset,
        outputFileType: AVFileType,
        outputURL: URL,
        videoSettings: [String: Any],
        videoComposition: AVVideoComposition? = nil,
        audioSettings: [String: Any],
        audioMix: AVAudioMix? = nil,
        completion: @escaping (Error?) -> Void) {
        guard !FileManager.default.fileExists(atPath: outputURL.path) else {
            completion(VAVideoConverterError.fileAlreadyExist)
            return
        }
        
        let timeRange = CMTimeRangeMake(kCMTimeZero, kCMTimePositiveInfinity)
        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: asset)
        } catch let error {
            completion(error)
            return
        }
        
        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: outputURL, fileType: outputFileType)
        } catch let error {
            completion(error)
            return
        }
        reader.timeRange = timeRange
        writer.shouldOptimizeForNetworkUse = true
        
        let videoTracks = asset.tracks(withMediaType: .video)
        
        guard !videoTracks.isEmpty else {
            completion(VAVideoConverterError.emptyTracks)
            return
        }
        
        let videoOutput = AVAssetReaderVideoCompositionOutput(videoTracks: videoTracks, videoSettings: nil)
        videoOutput.alwaysCopiesSampleData = false
        
        if let videoComposition = videoComposition {
            videoOutput.videoComposition = videoComposition
        } else {
            videoOutput.videoComposition = buildDefaultVideoComposition(asset, videoSettings: videoSettings)
        }
        
        if reader.canAdd(videoOutput) {
            reader.add(videoOutput)
        }
        
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = false
        
        if writer.canAdd(videoInput) {
            writer.add(videoInput)
        }
        
        let audioTracks = asset.tracks(withMediaType: .audio)
        
        var audioOutput: AVAssetReaderAudioMixOutput? = nil
        var audioInput: AVAssetWriterInput? = nil
        
        if !audioTracks.isEmpty {
            audioOutput = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: nil)
            audioOutput?.alwaysCopiesSampleData = false
            audioOutput?.audioMix = audioMix
            
            if reader.canAdd(audioOutput!) {
                reader.add(audioOutput!)
            }
            
            audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput?.expectsMediaDataInRealTime = false
            
            if writer.canAdd(audioInput!) {
                writer.add(audioInput!)
            }
        }
        
        writer.startWriting()
        reader.startReading()
        writer.startSession(atSourceTime: timeRange.start)
        
        let group = DispatchGroup()
        
        if !videoTracks.isEmpty {
            group.enter()
            videoInput.requestMediaDataWhenReady(on: .global()) {
                if !encodeReadySamplesFromOutput(videoOutput, input: videoInput, reader: reader, writer: writer) {
                    group.leave()
                }
            }
        }
        
        if let audioOutput = audioOutput, let audioInput = audioInput {
            group.enter()
            audioInput.requestMediaDataWhenReady(on: .global(), using: {
                if !encodeReadySamplesFromOutput(audioOutput, input: audioInput, reader: reader, writer: writer) {
                    group.leave()
                }
            })
        }
        
        group.notify(queue: .main) {
            guard writer.status != .cancelled else {
                try? FileManager.default.removeItem(at: outputURL)
                return
            }
            
            if writer.status == .failed {
                writer.cancelWriting()
                try? FileManager.default.removeItem(at: outputURL)
                completion(VAVideoConverterError.failed)
            } else {
                writer.finishWriting {
                    completion(nil)
                }
            }
        }
    }
    
    private static func encodeReadySamplesFromOutput(
        _ output: AVAssetReaderOutput,
        input: AVAssetWriterInput,
        reader: AVAssetReader,
        writer: AVAssetWriter
        ) -> Bool {
        while input.isReadyForMoreMediaData {
            if let sampleBuffer = output.copyNextSampleBuffer() {
                if reader.status != .reading || writer.status != .writing {
                    return false
                }
                
                if !input.append(sampleBuffer) {
                    return false
                }
                
            } else {
                input.markAsFinished()
                return false
            }
        }
        return true
    }
    
    private static func buildDefaultVideoComposition(
        _ asset: AVAsset,
        videoSettings: [String: Any]) -> AVMutableVideoComposition {
        let videoComposition = AVMutableVideoComposition()
        let videoTrack = asset.tracks(withMediaType: .video)[0]
        
        var trackFrameRate: Float = 0
        if let videoCompressionProperties = videoSettings[AVVideoCompressionPropertiesKey] as? [String: Any],
            let frameRate = videoCompressionProperties[AVVideoAverageNonDroppableFrameRateKey] as? Float {
            trackFrameRate = frameRate
        } else {
            trackFrameRate = videoTrack.nominalFrameRate
        }
        
        if trackFrameRate == 0 {
            trackFrameRate = 30
        }
        
        videoComposition.frameDuration = CMTimeMake(1, Int32(trackFrameRate))
        let targetSize = CGSize(
            width: videoSettings[AVVideoWidthKey] as? CGFloat ?? 0,
            height: videoSettings[AVVideoHeightKey] as? CGFloat ?? 0
        )
        var naturalSize = videoTrack.naturalSize
        var transform = videoTrack.preferredTransform
        
        if transform.ty == -560 {
            transform.ty = 0
        }
        
        if transform.tx == -560 {
            transform.tx = 0
        }
        
        let videoAngleInDegree  = atan2(transform.b, transform.a) * 180 / CGFloat.pi
        if videoAngleInDegree == 90 || videoAngleInDegree == -90 {
            let width = naturalSize.width
            naturalSize.width = naturalSize.height
            naturalSize.height = width
        }
        videoComposition.renderSize = naturalSize
        
        var ratio: CGFloat = 00
        let xratio = targetSize.width / naturalSize.width
        let yratio = targetSize.height / naturalSize.height
        ratio = min(xratio, yratio)
        
        let postWidth = naturalSize.width * ratio
        let postHeight = naturalSize.height * ratio
        let transx = (targetSize.width - postWidth) / 2
        let transy = (targetSize.height - postHeight) / 2
        
        var matrix = CGAffineTransform(translationX: transx / xratio, y: transy / yratio)
        matrix = matrix.scaledBy(x: ratio / xratio, y: ratio / yratio)
        transform = transform.concatenating(matrix)
        
        let passThroughInstruction = AVMutableVideoCompositionInstruction()
        passThroughInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, asset.duration)
        
        let passThroughLayer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        passThroughLayer.setTransform(transform, at: kCMTimeZero)
        passThroughInstruction.layerInstructions = [passThroughLayer]
        videoComposition.instructions = [passThroughInstruction]
        
        return videoComposition
    }
    
    private static func videoBitrateKbpsForPreset(_ preset: VAVideoConversionPreset) -> Int {
        switch preset {
        case .veryLow:
            return 400
        case .low:
            return 700
        case .medium:
            return 1100
        case .high:
            return 2500
        case .veryHigh:
            return 4000
        default:
            return 700
        }
    }
    
    static func videoSettingsForPreset(_ preset: VAVideoConversionPreset, size: CGSize) -> [String: Any] {
        let codecSettings = [AVVideoAverageBitRateKey: videoBitrateKbpsForPreset(preset) * 1000]
        return [
            AVVideoCodecKey: AVVideoCodecH264,
            AVVideoCompressionPropertiesKey: codecSettings,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height
        ]
    }
    
}
