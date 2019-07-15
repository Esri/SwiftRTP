//
//  RTPUtilities.swift
//  RTP Test
//
//  Created by Jonathan Wight on 7/1/15.
//  Copyright © 2015 3D Robotics Inc. All rights reserved.
//

import CoreMedia

import SwiftUtilities

public enum DataError: Swift.Error {
    case empty
}

public enum RTPError: Swift.Error {
    case unknownH264Type(UInt8)
    case unsupportedFeature(String)
    case skippedFrame(String)
    case posix(Int32, String)
    case streamReset
    case fragmentationUnitError(String, [UInt16])
}

public enum RTPEvent {
    case h264ParameterSetCycled
    case ppsReceived
    case spsReceived
    case naluProduced
    case badFragmentationUnit
    case errorInPipeline
    case h264FrameProduced
    case h264FrameSkipped
    case formatDescriptionProduced
    case sampleBufferProduced
    case packetReceived
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

private func freeBlock(_ refCon: UnsafeMutableRawPointer?, doomedMemoryBlock: UnsafeMutableRawPointer, sizeInBytes: Int) -> Void {
    let unmanagedData = Unmanaged<NSData>.fromOpaque(refCon!)
    unmanagedData.release()
}

// MARK: -

public extension DispatchData {
    
    func toCMBlockBuffer() throws -> CMBlockBuffer {
        
        return try withUnsafeBytes {
            (pointer: UnsafePointer<UInt8>) -> CMBlockBuffer in
            
            let data = NSMutableData(bytes: pointer, length: count)
            
            var source = CMBlockBufferCustomBlockSource()
            source.refCon = Unmanaged.passRetained(data).toOpaque()
            source.FreeBlock = freeBlock
            
            
            var blockBuffer: CMBlockBuffer?
            
            let result = CMBlockBufferCreateWithMemoryBlock(
                allocator: kCFAllocatorDefault,        // structureAllocator
                memoryBlock: data.mutableBytes,          // memoryBlock
                blockLength: data.length,                // blockLength
                blockAllocator: kCFAllocatorNull,           // blockAllocator
                customBlockSource: &source,                    // customBlockSource
                offsetToData: 0,                          // offsetToData
                dataLength: data.length,                // dataLength
                flags: 0,                          // flags
                blockBufferOut: &blockBuffer)               // newBBufOut
            if OSStatus(result) != kCMBlockBufferNoErr {
                throw SwiftUtilities.Error.unimplemented
            }
            
            assert(CMBlockBufferGetDataLength(blockBuffer!) == data.length)
            return blockBuffer!
        }
  
    }
}
