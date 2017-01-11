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

open class DecompressionSession {

    fileprivate var decompressionSession: VTDecompressionSession?

    open var formatDescription: CMVideoFormatDescription? {
        didSet {
            if let formatDescription = formatDescription, let decompressionSession = decompressionSession {
                if VTDecompressionSessionCanAcceptFormatDescription(decompressionSession, formatDescription) == false {
                    VTDecompressionSessionInvalidate(decompressionSession)
                    self.decompressionSession = nil
                }
            }
        }
    }

    open var imageBufferDecoded: ((_ imageBuffer: CVImageBuffer, _ presentationTimeStamp: CMTime, _ presentationDuration: CMTime) -> Void)?

    public init() {
    }

    open func decodeFrame(_ sampleBuffer: CMSampleBuffer) throws {

        if formatDescription == nil {
            formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) as CMVideoFormatDescription?
        }

        //VTDecompressionOutputCallbackBlock = (UnsafeMutableRawPointer?, OSStatus, VTDecodeInfoFlags, CVImageBuffer?, CMTime, CMTime) -> Swift.Void
        if decompressionSession == nil {
            let callback: VTDecompressionOutputCallbackBlock = {
                (sourceFrameRefCon: UnsafeMutableRawPointer?, status: OSStatus, infoFlags: VTDecodeInfoFlags, imageBuffer: CVImageBuffer?, presentationTimeStamp: CMTime, presentationDuration: CMTime) -> Void in
                if status != 0 {
                    return
                }
                self.imageBufferDecoded?(imageBuffer!, presentationTimeStamp, presentationDuration)
            }

#if os(iOS)
            let videoDecoderSpecification: [String: AnyObject]? = nil
            let destinationImageBufferAttributes: [String: AnyObject] = [
                kCVPixelBufferOpenGLESCompatibilityKey as String: true as AnyObject,
                kCVPixelBufferMetalCompatibilityKey as String: true as AnyObject,
            // TODO: This is crashing Swift 2.0b6. Hardcode constant for now.
            // kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
                kCVPixelBufferPixelFormatTypeKey as String: 875704438 as AnyObject
            ]
#else
            let videoDecoderSpecification: [String: AnyObject] = [
                kVTVideoDecoderSpecification_EnableHardwareAcceleratedVideoDecoder as String: true as AnyObject
            ]

            let destinationImageBufferAttributes: [String: AnyObject] = [
                kCVPixelBufferOpenGLCompatibilityKey as String: true as AnyObject,

            // TODO: This is crashing Swift 2.0b6. Hardcode constant for now.
            // kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
                kCVPixelBufferPixelFormatTypeKey as String: 875704438 as AnyObject
            ]
#endif

            var unmanagedDecompressionSession: Unmanaged <VTDecompressionSession>?
            let result = VTDecompressionSessionCreateWithBlock(kCFAllocatorDefault, formatDescription, videoDecoderSpecification as CFDictionary!, destinationImageBufferAttributes as CFDictionary!, callback, &unmanagedDecompressionSession)
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

    public func process(_ input: H264Processor.Output) throws {
        switch input {
            case .formatDescription(let formatDescription):
                self.formatDescription = formatDescription
            case .sampleBuffer(let sampleBuffer):
                try self.decodeFrame(sampleBuffer)
        }
    }
}
