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
    case streamReset
    case fragmentationUnitError(String,[UInt16])
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
            case .streamReset:
                return "streamReset"
            case .fragmentationUnitError(let description, let sequenceNumbers):
                return "fragmentationUnitError(\(description), \(sequenceNumbers))"
        }
    }
}

// MARK: -

func freeBlock(refCon: UnsafeMutablePointer<Void>, doomedMemoryBlock: UnsafeMutablePointer<Void>, sizeInBytes: Int) -> Void {
    let unmanagedData = Unmanaged<dispatch_data_t>.fromOpaque(COpaquePointer(refCon))
    unmanagedData.release()
}

public extension DispatchData {

    func toCMBlockBuffer() throws -> CMBlockBuffer {

        let blockBuffer = try createMap() {
            (data, buffer) -> CMBlockBuffer in

            let dispatch_data = data.data
            var source = CMBlockBufferCustomBlockSource()
            source.refCon = UnsafeMutablePointer<Void> (Unmanaged.passRetained(dispatch_data).toOpaque())
            source.FreeBlock = freeBlock

            var blockBuffer: CMBlockBuffer?
            let result = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, UnsafeMutablePointer <Void> (buffer.baseAddress), buffer.length, kCFAllocatorNull, &source, 0, buffer.length, 0, &blockBuffer)
            if OSStatus(result) != kCMBlockBufferNoErr {
                throw Error.todo
            }

            assert(CMBlockBufferGetDataLength(blockBuffer!) == buffer.count)
            return blockBuffer!
        }
        return blockBuffer
    }
}

// MARK: -

public func makeFormatDescription(SPS:H264NALU, PPS:H264NALU) throws -> CMFormatDescription {
    return try makeFormatDescription(SPS.data, PPS: PPS.data)
}

public func makeFormatDescription(SPS:DispatchData <Void>, PPS:DispatchData <Void>) throws -> CMFormatDescription {

    return try PPS.createMap() {
        (_, PPSBuffer) in

        return try SPS.createMap() {
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

            var formatDescription: CMFormatDescription?
            let result = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault, pointers.count, pointers, sizes, NALUnitHeaderLength, &formatDescription)
            if result != 0 {
                throw makeOSStatusError(result, description: "CMVideoFormatDescriptionCreateFromH264ParameterSets failed")
            }
            return formatDescription!
        }
    }
}
