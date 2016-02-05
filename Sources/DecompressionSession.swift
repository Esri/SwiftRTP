//
//  Test.swift
//  RTP Test
//
//  Created by Jonathan Wight on 6/29/15.
//  Copyright © 2015 3D Robotics Inc. All rights reserved.
//

import VideoToolbox

import Darwin
import Foundation
import VideoToolbox
import CoreVideo

import SwiftUtilities

public class DecompressionSession {

    private var decompressionSession: VTDecompressionSession?

    public var formatDescription: CMVideoFormatDescription? {
        didSet {
            if let formatDescription = formatDescription, let decompressionSession = decompressionSession {
                if VTDecompressionSessionCanAcceptFormatDescription(decompressionSession, formatDescription) == false {
                    VTDecompressionSessionInvalidate(decompressionSession)
                    self.decompressionSession = nil
                }
            }
        }
    }

    public var imageBufferDecoded: ((imageBuffer: CVImageBuffer, presentationTimeStamp: CMTime, presentationDuration: CMTime) -> Void)?

    public init() {
    }

    public func decodeFrame(sampleBuffer: CMSampleBuffer) throws {

        if formatDescription == nil {
            formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) as CMVideoFormatDescription?
        }

        if decompressionSession == nil {
            let callback = {
                (sourceFrameRefCon: UnsafeMutablePointer<Void>, status: OSStatus, infoFlags: VTDecodeInfoFlags, imageBuffer: CVImageBuffer!, presentationTimeStamp: CMTime, presentationDuration: CMTime) -> Void in
                if status != 0 {
                    return
                }
                self.imageBufferDecoded?(imageBuffer: imageBuffer, presentationTimeStamp: presentationTimeStamp, presentationDuration: presentationDuration)
            }

#if os(iOS)
            let videoDecoderSpecification: [String: AnyObject]? = nil
            let destinationImageBufferAttributes: [String: AnyObject] = [
                kCVPixelBufferOpenGLESCompatibilityKey as String: true,
                kCVPixelBufferMetalCompatibilityKey as String: true,
            // TODO: This is crashing Swift 2.0b6. Hardcode constant for now.
            // kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
                kCVPixelBufferPixelFormatTypeKey as String: 875704438
            ]
#else
            let videoDecoderSpecification: [String: AnyObject] = [
                kVTVideoDecoderSpecification_EnableHardwareAcceleratedVideoDecoder as String: true
            ]

            let destinationImageBufferAttributes: [String: AnyObject] = [
                kCVPixelBufferOpenGLCompatibilityKey as String: true,

            // TODO: This is crashing Swift 2.0b6. Hardcode constant for now.
            // kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
                kCVPixelBufferPixelFormatTypeKey as String: 875704438
            ]
#endif

            var unmanagedDecompressionSession: Unmanaged <VTDecompressionSession>?
            let result = VTDecompressionSessionCreateWithBlock(kCFAllocatorDefault, formatDescription, videoDecoderSpecification, destinationImageBufferAttributes, callback, &unmanagedDecompressionSession)
            if result != 0 {
                throw makeOSStatusError(result, description: "Unable to create VTDecompressionSession")
            }

            decompressionSession = unmanagedDecompressionSession?.takeRetainedValue()
        }

        let frameFlags = VTDecodeFrameFlags(rawValue: VTDecodeFrameFlags._EnableAsynchronousDecompression.rawValue | VTDecodeFrameFlags._1xRealTimePlayback.rawValue)
        var decodeFlags = VTDecodeInfoFlags()
        let result = VTDecompressionSessionDecodeFrame(decompressionSession!, sampleBuffer, frameFlags, nil, &decodeFlags)
        if result != 0 {
            throw makeOSStatusError(result, description: "VTDecompressionSessionDecodeFrame failed (flags: \(decodeFlags))")
        }
    }
}

// MARK: -

public extension DecompressionSession {

    public func process(input: H264Processor.Output) throws {
        switch input {
            case .FormatDescription(let formatDescription):
                self.formatDescription = formatDescription
            case .SampleBuffer(let sampleBuffer):
                try self.decodeFrame(sampleBuffer)
        }
    }
}
