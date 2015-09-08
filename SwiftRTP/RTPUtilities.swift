//
//  RTPUtilities.swift
//  RTP Test
//
//  Created by Jonathan Wight on 7/1/15.
//  Copyright © 2015 3D Robotics Inc. All rights reserved.
//

import CoreMedia

import SwiftUtilities

public enum RTPError: ErrorType {
    case unknownH264Type(UInt8)
    case unsupportedFeature(String)
    case skippedFrame(String)
    case generic(String)
    case posix(Int32,String)
}

extension RTPError: CustomStringConvertible {
    public var description: String {
        switch self {
            case .unknownH264Type(let type):
                return "Unknown H264 Type: \(type)"
            case .unsupportedFeature(let string):
                return "Unsupported Feature: \(string)"
            case .skippedFrame(let string):
                return "Skipping Frame: \(string)"
            case .generic(let string):
                return "\(string)"
            case .posix(let result, let string):
                return "\(result): \(string)"
        }
    }
}

// MARK: -

public extension DispatchData {

    func toCMBlockBuffer(inout error:ErrorType?) -> CMBlockBuffer? {

        let blockBuffer = createMap() {
            (data, buffer) -> CMBlockBuffer? in

            var data: dispatch_data_t? = data.data

            var source = CMBlockBufferCustomBlockSource()
            MakeBlockBufferCustomBlockSource(&source) {
                data = nil
                return
            }

            var blockBuffer: CMBlockBuffer?
            let result = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, UnsafeMutablePointer <Void> (buffer.baseAddress), buffer.length, kCFAllocatorNull, &source, 0, buffer.length, 0, &blockBuffer)
            if OSStatus(result) != kCMBlockBufferNoErr {
                error = Error.todo
                return nil
            }

            assert(CMBlockBufferGetDataLength(blockBuffer!) == buffer.count)
            return blockBuffer
        }
        return blockBuffer
    }
}

// MARK: -

public func makeFormatDescription(SPS:H264NALU, PPS:H264NALU, inout error:ErrorType?) -> CMFormatDescription? {
    return makeFormatDescription(SPS.data, PPS: PPS.data, error: &error)
}

public func makeFormatDescription(SPS:DispatchData <Void>, PPS:DispatchData <Void>, inout error:ErrorType?) -> CMFormatDescription? {

    return PPS.createMap() {
        (_, PPSBuffer) in

        return SPS.createMap() {
            (_, SPSBuffer) in

            let pointers:[UnsafePointer <UInt8>] = [
                UnsafePointer <UInt8> (PPSBuffer.baseAddress),
                UnsafePointer <UInt8> (SPSBuffer.baseAddress),
            ]
            let sizes:[Int] = [
                PPSBuffer.count,
                SPSBuffer.count,
            ]

            // Size of NALU length headers in AVCC/MPEG-4 format (can be 1, 2, or 4).
            let NALUnitHeaderLength:Int32 = 4

            var unmanagedFormatDescription: CMFormatDescription?
            let result = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault, pointers.count, pointers, sizes, NALUnitHeaderLength, &unmanagedFormatDescription)
            if result != 0 {
                error = makeOSStatusError(result, description: "CMVideoFormatDescriptionCreateFromH264ParameterSets failed")
            }
            return unmanagedFormatDescription
        }
    }
}
