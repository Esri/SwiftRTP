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
    case UnknownH264Type(UInt8)
    case UnsupportedFeature(String)
    case SkippedFrame(String)
    case POSIX(Int32, String)
    case StreamReset
    case FragmentationUnitError(String, [UInt16])
}

public enum RTPEvent {
    case H264ParameterSetCycled
    case PPSReceived
    case SPSReceived
    case NALUProduced
    case BadFragmentationUnit
    case ErrorInPipeline
    case H264FrameProduced
    case H264FrameSkipped
    case FormatDescriptionProduced
    case SampleBufferProduced
    case PacketReceived
}



extension RTPError: CustomStringConvertible {
    public var description: String {
        switch self {
            case .UnknownH264Type(let type):
                return "Unknown H264 Type: \(type)"
            case .UnsupportedFeature(let string):
                return "Unsupported Feature: \(string)"
            case .SkippedFrame(let string):
                return "Skipping Frame: \(string)"
            case .POSIX(let result, let string):
                return "\(result): \(string)"
            case .StreamReset:
                return "streamReset"
            case .FragmentationUnitError(let description, let sequenceNumbers):
                return "fragmentationUnitError(\(description), \(sequenceNumbers))"
        }
    }
}

// MARK: -

private func freeBlock(refCon: UnsafeMutablePointer<Void>, doomedMemoryBlock: UnsafeMutablePointer<Void>, sizeInBytes: Int) -> Void {
    let unmanagedData = Unmanaged<dispatch_data_t>.fromOpaque(COpaquePointer(refCon))
    unmanagedData.release()
}

// MARK: -

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
                throw Error.Unimplemented
            }

            assert(CMBlockBufferGetDataLength(blockBuffer!) == buffer.count)
            return blockBuffer!
        }
        return blockBuffer
    }
}
