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
//import VideoToolbox
//import CoreMedia
//import CoreVideo

public class DecompressionSession {

    public var formatDescription:CMVideoFormatDescription! {
        didSet {
//            if formatDescription == oldValue {
//                return
//            }
//            guard let decompressionSession = decompressionSession else {
//                return
//            }
//            print(VTDecompressionSessionCanAcceptFormatDescription(decompressionSession, formatDescription))
        }
    }

    public var decompressionSession:VTDecompressionSession?

    public init() {
    }

    public var imageBufferDecoded:((imageBuffer:CVImageBuffer, presentationTimeStamp:CMTime, presentationDuration:CMTime) -> Void)?

    public func decodeFrame(sampleBuffer:CMSampleBuffer, inout error:ErrorType?) -> Bool {

        if decompressionSession == nil {

            let callback = {
                (sourceFrameRefCon:UnsafeMutablePointer<Void>, status:OSStatus, infoFlags:VTDecodeInfoFlags, imageBuffer:CVImageBuffer!, presentationTimeStamp:CMTime, presentationDuration:CMTime) -> Void in
                if status != 0 {
                    return
                }
                self.imageBufferDecoded?(imageBuffer: imageBuffer, presentationTimeStamp: presentationTimeStamp, presentationDuration: presentationDuration)
            }

            assert(formatDescription != nil)

            let videoDecoderSpecification:NSDictionary? = nil
//            let videoDecoderSpecification:NSDictionary = [
//                kVTVideoDecoderSpecification_EnableHardwareAcceleratedVideoDecoder as String: true
//            ]

            let destinationImageBufferAttributes:NSDictionary = [
                kCVPixelFormatName as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
            ]

            var unmanagedDecompressionSession:Unmanaged <VTDecompressionSession>?
            let result = VTDecompressionSessionCreateWithBlock(kCFAllocatorDefault, formatDescription, videoDecoderSpecification, destinationImageBufferAttributes, callback, &unmanagedDecompressionSession)
            if result != 0 {
                error = makeOSStatusError(result, description: "Unable to create VTDecompressionSession")
                return false
            }

            decompressionSession = unmanagedDecompressionSession?.takeRetainedValue()
        }

        var flags:VTDecodeInfoFlags = VTDecodeInfoFlags()
        let result = VTDecompressionSessionDecodeFrame(decompressionSession!, sampleBuffer, VTDecodeFrameFlags(), nil, &flags)
        if result != 0 {
            error = makeOSStatusError(result, description: "VTDecompressionSessionDecodeFrame failed (flags: \(flags))")
            return false
        }

        return true
    }
}

// MARK: -

public extension DecompressionSession {

    func process(input:H264Processor.Output, inout error:ErrorType?) -> Bool {
        switch input {
            case .formatDescription(let formatDescription):
                self.formatDescription = formatDescription
                return true
            case .sampleBuffer(let sampleBuffer):
                return decodeFrame(sampleBuffer, error: &error)
        }
    }
}
