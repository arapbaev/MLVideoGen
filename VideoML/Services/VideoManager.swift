//
//  VideoGenerator.swift
//  VideoML
//
//  Created by Aslan Arapbaev on 3/27/23.
//

import AVFoundation
import Photos
import UIKit

import AVFoundation

enum ConstructionError: Error {
    case invalidImage, invalidURL, exportSessionFail, invalidAsset, invalidAssetTrack
}

typealias SequenceAndTimeRanges = (imagesBack: [UIImage], timeRangesBack: [(startTime: Double, endTime: Double)], imagesMid: [UIImage], timeRangesMid: [(startTime: Double, endTime: Double)], imagesFront: [UIImage], timeRangesFront: [(startTime: Double, endTime: Double)])

class VideoManager {
    enum VideoEffect {
        case sequence, sequenceRandom
    }
    
    func createVideo(_ url: URL, images: [ImageData], effect: VideoEffect) async throws -> URL? {
        guard let image = images.first?.original.cgImage,
              let audioURL = Bundle.main.url(forResource: "music", withExtension: "aac")
        else {
            throw ConstructionError.invalidAsset
        }
        
        // create composition with audio and solid color video
        let videoSize: CGSize = .init(width: image.width, height: image.height)
        let audioAsset = AVURLAsset(url: audioURL)
        let videoAsset = AVURLAsset(url: url)
        let composition = AVMutableComposition()
        
        guard let videoCompositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let videoAssetTrack = try await videoAsset.loadTracks(withMediaType: .video).first,
              let audioCompositionTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid),
              let audioAssetTrack = try await audioAsset.loadTracks(withMediaType: .audio).first
        else {
            print("Something is wrong with the asset.")
            throw ConstructionError.invalidAssetTrack
        }
        
        let timeRange = CMTimeRange(start: .zero, duration: try await audioAsset.load(.duration))
        try videoCompositionTrack.insertTimeRange(timeRange, of: videoAssetTrack, at: .zero)
        try audioCompositionTrack.insertTimeRange(timeRange, of: audioAssetTrack, at: .zero)
        
        videoCompositionTrack.preferredTransform = try await videoAssetTrack.load(.preferredTransform)
        
        // create layers for image animations
        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: videoSize)
        let backLayer = CALayer()
        backLayer.frame = CGRect(origin: .zero, size: videoSize)
        let midLayer = CALayer()
        midLayer.frame = CGRect(origin: .zero, size: videoSize)
        let frontLayer = CALayer()
        frontLayer.frame = CGRect(origin: .zero, size: videoSize)
        
        let outputLayer = CALayer()
        outputLayer.frame = CGRect(origin: .zero, size: videoSize)
        outputLayer.addSublayer(videoLayer)
        outputLayer.addSublayer(backLayer)
        outputLayer.addSublayer(midLayer)
        outputLayer.addSublayer(frontLayer)
        
        // generate images and time ranges for each layer
        let duration = try await audioAsset.load(.duration).seconds
        let data = generateImageSequenceAndTimeRanges(images: images, totalDuration: duration, effect: effect)
        
        let animationGroupBack = createAnimationGroup(images: data.imagesBack, timeRanges: data.timeRangesBack)
        backLayer.add(animationGroupBack, forKey: "animationGroupBack")
        
        let animationGroupMid = createAnimationGroup(images: data.imagesMid, timeRanges: data.timeRangesMid)
        midLayer.add(animationGroupMid, forKey: "animationGroupMid")
        
        let animationGroupFront = createAnimationGroup(images: data.imagesFront, timeRanges: data.timeRangesFront)
        frontLayer.add(animationGroupFront, forKey: "imageAnimationFront")
        
        // create composition with instructions to export
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = videoSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: outputLayer)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
        videoComposition.instructions = [instruction]
        
        let layerInstruction = try await compositionLayerInstruction(for: videoCompositionTrack, assetTrack: videoAssetTrack)
        instruction.layerInstructions = [layerInstruction]
        
        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)
        else {
            print("Cannot create export session.")
            throw ConstructionError.exportSessionFail
        }
        
        
        let exportURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("new.mov")
        
        if FileManager.default.fileExists(atPath: exportURL.path) {
            try FileManager.default.removeItem(atPath: exportURL.path)
        }
        
        export.videoComposition = videoComposition
        export.outputFileType = .mov
        export.outputURL = exportURL
        
        return await assetExport(session: export, url: exportURL)
    }
    
    /// Adds image at specific time range
    private func singleAddImageAnimation(image: UIImage, startTime: Double, endTime: Double) -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: "contents")
        animation.fromValue = image.cgImage
        animation.toValue = image.cgImage
        animation.beginTime = startTime
        animation.duration = endTime - startTime
        animation.fillMode = .removed
        animation.isRemovedOnCompletion = true
        return animation
    }
    
    /// Creates animation group from arrays of images and time ranges
    private func createAnimationGroup(images: [UIImage], timeRanges: [(startTime: Double, endTime: Double)]) -> CAAnimation {
        let animationGroup = CAAnimationGroup()
        animationGroup.animations = zip(images, timeRanges).map {
            singleAddImageAnimation(image: $0, startTime: $1.startTime, endTime: $1.endTime)
        }
        animationGroup.duration = timeRanges.last?.endTime ?? 0
        animationGroup.fillMode = .both
        animationGroup.beginTime = AVCoreAnimationBeginTimeAtZero
        animationGroup.isRemovedOnCompletion = false
        
        return animationGroup
    }
    
    /// Generates image and time range sequences for each layer (back, mid, front)
    private func generateImageSequenceAndTimeRanges(images: [ImageData], totalDuration: Double, effect: VideoEffect) -> SequenceAndTimeRanges {
        var imagesBack: [UIImage] = []
        var timeRangesBack: [(startTime: Double, endTime: Double)] = []
        
        var imagesMid: [UIImage] = []
        var timeRangesMid: [(startTime: Double, endTime: Double)] = []
        
        var imagesFront: [UIImage] = []
        var timeRangesFront: [(startTime: Double, endTime: Double)] = []
        
        let numIntervals = images.count
        let intervalDuration = totalDuration / Double(numIntervals)
        
        var currentTimeFront = intervalDuration / 2
        var currentTimeMid = 0.0
        var currentTimeBack = 0.0
        
        for (index, imageData) in images.enumerated() {
            if effect == .sequenceRandom {
                if index == 0 {
                    imagesBack.append(imageData.original)
                    let endTimeBack = currentTimeBack + intervalDuration
                    timeRangesBack.append((startTime: currentTimeBack, endTime: endTimeBack))
                    currentTimeBack = endTimeBack
                } else {
                    imagesBack.append(imageData.original)
                    let endTimeBack = currentTimeBack + intervalDuration
                    timeRangesBack.append((startTime: currentTimeBack, endTime: currentTimeBack + (intervalDuration / 2)))
                    imagesBack.append(imageData.randomBack)
                    timeRangesBack.append((startTime: currentTimeBack + (intervalDuration / 2), endTime: endTimeBack))
                    currentTimeBack = endTimeBack
                }
            } else {
                imagesBack.append(imageData.original)
                let endTimeBack = currentTimeBack + intervalDuration
                timeRangesBack.append((startTime: currentTimeBack, endTime: endTimeBack))
                currentTimeBack = endTimeBack
            }
            
            if index < images.count - 1, let nextFront = images[index + 1].front {
                imagesMid.append(nextFront)
                let startTimeMid = currentTimeMid + intervalDuration
                timeRangesMid.append((startTime: startTimeMid, endTime: startTimeMid + intervalDuration))
                currentTimeMid = startTimeMid
                
                imagesFront.append(nextFront)
                let endTime = currentTimeFront + intervalDuration
                timeRangesFront.append((startTime: currentTimeFront, endTime: endTime))
                currentTimeFront = endTime
            }
        }
        
        return (imagesBack, timeRangesBack, imagesMid, timeRangesMid, imagesFront, timeRangesFront)
    }
    
}

// MARK: Helpers
extension VideoManager {
    private func assetExport(session: AVAssetExportSession, url: URL) async -> URL? {
        return await withCheckedContinuation({ continuation in
            session.exportAsynchronously {
                switch session.status {
                case .completed:
                    return continuation.resume(returning: url)
                default:
                    debugPrint("Something went wrong during export.")
                    debugPrint(session.error ?? "unknown error")
                    return continuation.resume(returning: nil)
                }
            }
        })
    }
    
    private func compositionLayerInstruction(for track: AVCompositionTrack, assetTrack: AVAssetTrack) async throws -> AVMutableVideoCompositionLayerInstruction {
        let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        let transform = try await assetTrack.load(.preferredTransform)
        
        instruction.setTransform(transform, at: .zero)
        
        return instruction
    }
    
    func createEmptyVideo() async throws -> URL? {
        guard let image = UIImage(named: "solid"),
              let staticImage = CIImage(image: image) else {
            throw ConstructionError.invalidImage
        }
        var pixelBuffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
             kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        let width: Int = Int(staticImage.extent.size.width)
        let height: Int = Int(staticImage.extent.size.height)
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs, &pixelBuffer)
        
        let context = CIContext()
        context.render(staticImage, to: pixelBuffer!)
        
        guard let outputMovieURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("solidColor.mov") else {
            throw ConstructionError.invalidURL
        }
        
            // delete any old file
        try FileManager.default.removeItem(at: outputMovieURL)
        
        guard let assetwriter = try? AVAssetWriter(outputURL: outputMovieURL, fileType: .mp4)
        else {
            debugPrint("Cannot create assetwriter.")
            return nil
        }
        
        let assetWriterSettings = [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey : width, AVVideoHeightKey: height] as [String : Any]
        let assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: assetWriterSettings)
        let assetWriterAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterInput, sourcePixelBufferAttributes: nil)
        
        assetwriter.add(assetWriterInput)
        
            // begin the session
        assetwriter.startWriting()
        assetwriter.startSession(atSourceTime: CMTime.zero)
        
            // determine how many frames we need to generate
        let framesPerSecond = 30
        let totalFrames = 1 * framesPerSecond
        var frameCount = 0
        
        while frameCount < totalFrames {
            if assetWriterInput.isReadyForMoreMediaData {
                let frameTime = CMTimeMake(value: Int64(frameCount), timescale: Int32(framesPerSecond))
                assetWriterAdaptor.append(pixelBuffer!, withPresentationTime: frameTime)
                
                frameCount+=1
            }
        }
        
            //close the session
        assetWriterInput.markAsFinished()
        await assetwriter.finishWriting()
        
        pixelBuffer = nil
        
        return outputMovieURL
    }
}
