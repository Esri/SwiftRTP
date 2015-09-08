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

public class DecompressionSession {

    private var decompressionSession:VTDecompressionSession?

    public var formatDescription:CMVideoFormatDescription? {
        didSet {
            if let formatDescription = formatDescription, let decompressionSession = decompressionSession {
                if VTDecompressionSessionCanAcceptFormatDescription(decompressionSession, formatDescription) == 0 {
                    VTDecompressionSessionInvalidate(decompressionSession)
                    self.decompressionSession = nil
                }
            }
        }
    }

    public var imageBufferDecoded:((imageBuffer:CVImageBuffer, presentationTimeStamp:CMTime, presentationDuration:CMTime) -> Void)?

    public init() {
    }

    public func decodeFrame(sampleBuffer:CMSampleBuffer, inout error:ErrorType?) -> Bool {

        if formatDescription == nil {
            formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) as CMVideoFormatDescription
        }

        if decompressionSession == nil {
            let callback = {
                (sourceFrameRefCon:UnsafeMutablePointer<Void>, status:OSStatus, infoFlags:VTDecodeInfoFlags, imageBuffer:CVImageBuffer!, presentationTimeStamp:CMTime, presentationDuration:CMTime) -> Void in
                if status != 0 {
                    return
                }
                self.imageBufferDecoded?(imageBuffer: imageBuffer, presentationTimeStamp: presentationTimeStamp, presentationDuration: presentationDuration)
            }

#if TARGET_OS_IPHONE
            let videoDecoderSpecification:NSDictionary? = nil
            let destinationImageBufferAttributes:NSDictionary = [
                kCVPixelBufferOpenGLESCompatibilityKey as String: true,
                kCVPixelBufferMetalCompatibilityKey as String: true,
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
            ]
#else
            let videoDecoderSpecification:NSDictionary = [
                // kVTVideoDecoderSpecification_EnableHardwareAcceleratedVideoDecoder as String: true
                "EnableHardwareAcceleratedVideoDecoder": true
            ]
            let destinationImageBufferAttributes:NSDictionary = [
                kCVPixelBufferOpenGLCompatibilityKey as String: true,
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
            ]
#endif

            var unmanagedDecompressionSession:Unmanaged <VTDecompressionSession>?
            let result = VTDecompressionSessionCreateWithBlock(kCFAllocatorDefault, formatDescription, videoDecoderSpecification, destinationImageBufferAttributes, callback, &unmanagedDecompressionSession)
            if result != 0 {
                error = makeOSStatusError(result, description: "Unable to create VTDecompressionSession")
                return false
            }

            decompressionSession = unmanagedDecompressionSession?.takeRetainedValue()
        }

        let frameFlags = VTDecodeFrameFlags(kVTDecodeFrame_EnableAsynchronousDecompression)
        var decodeFlags = VTDecodeInfoFlags()
        let result = VTDecompressionSessionDecodeFrame(decompressionSession!, sampleBuffer, frameFlags, nil, &decodeFlags)
        if result != 0 {
            error = makeOSStatusError(result, description: "VTDecompressionSessionDecodeFrame failed (flags: \(decodeFlags))")
            return false
        }

        return true
    }
}

// MARK: -

public extension DecompressionSession {

    public func process(input:H264Processor.Output, inout error:ErrorType?) -> Bool {
        switch input {
            case .formatDescription(let formatDescription):
                self.formatDescription = formatDescription
                return true
            case .sampleBuffer(let sampleBuffer):
                let result = self.decodeFrame(sampleBuffer, error: &error)
                if !result {
                    if let decompressionSession = self.decompressionSession {
                        VTDecompressionSessionInvalidate(decompressionSession)
                        self.decompressionSession = nil
                    }
                }
                return result
        }
    }
}
