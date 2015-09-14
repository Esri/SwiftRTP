//
//  H264Processor.swift
//  RTP Test
//
//  Created by Jonathan Wight on 6/30/15.
//  Copyright © 2015 3D Robotics Inc. All rights reserved.
//

import CoreMedia

import SwiftUtilities

let H264ClockRate:Int32 = 90_000

public class H264Processor {

    public enum Output {
        case formatDescription(CMFormatDescription)
        case sampleBuffer(CMSampleBuffer)
    }

    public internal(set) var lastSPS:H264NALU?
    public internal(set) var lastPPS:H264NALU?
    public var defaultFormatDescription:CMFormatDescription?
    public var lastFormatDescription:CMFormatDescription?

    var firstTimestamp: UInt32?
    var lastTimestamp: UInt32?

    public init() {
    }

    public func process(nalu:H264NALU) throws -> Output? {

        if firstTimestamp == nil {
            firstTimestamp = nalu.timestamp
        }

        var result:Output? = nil

        if let type = nalu.type {
            switch type {
                case .SliceIDR, .SliceNonIDR:
                    result = try processVideoFrame(nalu)
                case .SPS:
                    lastSPS = nalu
                case .PPS:
                    lastPPS = nalu
            }

            if let SPS = lastSPS, let PPS = lastPPS {
                let formatDescription = try makeFormatDescription(SPS, PPS: PPS)
                self.lastFormatDescription = formatDescription
                // TODO: Do we want to do this
                lastSPS = nil
                lastPPS = nil
                result = .formatDescription(formatDescription)
            }
        }
        else {
            throw RTPError.unknownH264Type(nalu.rawType)
        }

        lastTimestamp = nalu.timestamp

        return result
    }

    public func processVideoFrame(nalu:H264NALU) throws -> Output {
        if let formatDescription = lastFormatDescription {
            let sampleBuffer = try nalu.toCMSampleBuffer(firstTimestamp!, formatDescription: formatDescription)
            return .sampleBuffer(sampleBuffer)
        }
        else {
            throw RTPError.skippedFrame("No formatDescription, skipping frame.")
        }
    }
}

// MARK: -

public extension H264NALU {

    func toCMSampleBuffer(firstTimestamp:UInt32, formatDescription:CMFormatDescription) throws -> CMSampleBuffer {

        if timestamp < firstTimestamp {
            throw SwiftUtilities.Error.generic("Got a timestamp from before first timestamp.")
        }

        // Prepend the size of the data to the data as a 32-bit network endian uint. (keyword: "elementary stream")
        let headerValue = UInt32(data.length)
        let headerData = DispatchData <Void>(value:headerValue.bigEndian)
        let sizedData = headerData + data

        let blockBuffer = try sizedData.toCMBlockBuffer()

        // So what about STAP???? From CMSampleBufferCreate "Behavior is undefined if samples in a CMSampleBuffer (or even in multiple buffers in the same stream) have the same presentationTimeStamp"


        // Computer the duration and time
        let duration = kCMTimeInvalid // CMTimeMake(3000, H264ClockRate) // TODO: 1/30th of a second. Making this up.
        let time = CMTimeMake(Int64(timestamp - firstTimestamp), H264ClockRate)

        // Inputs to CMSampleBufferCreate
        let timingInfo:[CMSampleTimingInfo] = [CMSampleTimingInfo(duration: duration, presentationTimeStamp: time, decodeTimeStamp: time)]
        let sampleSizes:[Int] = [CMBlockBufferGetDataLength(blockBuffer)]

        // Outputs from CMSampleBufferCreate
        var sampleBuffer: CMSampleBuffer?

        let result = CMSampleBufferCreate(
            kCFAllocatorDefault,            // allocator: CFAllocator?,
            blockBuffer,                    // dataBuffer: CMBlockBuffer?,
            true,                           // dataReady: Boolean,
            nil,                            // makeDataReadyCallback: CMSampleBufferMakeDataReadyCallback?,
            nil,                            // makeDataReadyRefcon: UnsafeMutablePointer<Void>,
            formatDescription,              // formatDescription: CMFormatDescription?,
            1,                              // numSamples: CMItemCount,
            timingInfo.count,               // numSampleTimingEntries: CMItemCount,
            timingInfo,                     // sampleTimingArray: UnsafePointer<CMSampleTimingInfo>,
            sampleSizes.count,              // numSampleSizeEntries: CMItemCount,
            sampleSizes,                    // sampleSizeArray: UnsafePointer<Int>,
            &sampleBuffer                   // sBufOut: UnsafeMutablePointer<Unmanaged<CMSampleBuffer>?>
        )

        if result != 0 {
            throw makeOSStatusError(result, description:"CMSampleBufferCreate() failed")
        }

        return sampleBuffer!
    }

}

// MARK: -
