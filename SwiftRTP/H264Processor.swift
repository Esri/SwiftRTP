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

    public func process(nalu:H264NALU, inout error:ErrorType?) -> Output? {

        if firstTimestamp == nil {
            firstTimestamp = nalu.timestamp
        }

        var result:Output? = nil

        if let type = nalu.type {
            switch type {
                case .SliceIDR, .SliceNonIDR:
                    result = processVideoFrame(nalu, error:&error)
                case .SPS:
                    lastSPS = nalu
                case .PPS:
                    lastPPS = nalu
            }

            if let SPS = lastSPS, let PPS = lastPPS {
                if let formatDescription = makeFormatDescription(SPS, PPS: PPS, error:&error) {
                    self.lastFormatDescription = formatDescription
                    // TODO: Do we want to do this
                    lastSPS = nil
                    lastPPS = nil
                    result = .formatDescription(formatDescription)
                }
            }
        }
        else {
            error = RTPError.unknownH264Type(nalu.rawType)
        }

        lastTimestamp = nalu.timestamp

        return result
    }

    public func processVideoFrame(nalu:H264NALU, inout error:ErrorType?) -> Output? {
        if let formatDescription = lastFormatDescription {
            if let sampleBuffer = nalu.toCMSampleBuffer(firstTimestamp!, formatDescription: formatDescription, error:&error) {
                return .sampleBuffer(sampleBuffer)
            }
        }
        else {
            error = RTPError.skippedFrame("No formatDescription, skipping frame.")
        }
        return nil
    }
}

// MARK: -

public extension H264NALU {

    func toCMSampleBuffer(firstTimestamp:UInt32, formatDescription:CMFormatDescription, inout error:ErrorType?) -> CMSampleBuffer? {

        if timestamp < firstTimestamp {
            error = SwiftUtilities.Error.generic("Got a timestamp from before first timestamp.")
            return nil
        }

        // Prepend the size of the data to the data as a 32-bit network endian uint. (keyword: "elementary stream")
        let headerValue = UInt32(data.length)
        let headerData = DispatchData <Void>(value:headerValue.bigEndian)
        let sizedData = headerData + data

        if let blockBuffer = sizedData.toCMBlockBuffer(&error) {

            // So what about STAP???? From CMSampleBufferCreate "Behavior is undefined if samples in a CMSampleBuffer (or even in multiple buffers in the same stream) have the same presentationTimeStamp"


            // Computer the duration and time
            let duration = kCMTimeInvalid // CMTimeMake(3000, H264ClockRate) // TODO: 1/30th of a second. Making this up.
            let time = CMTimeMake(Int64(timestamp - firstTimestamp), H264ClockRate)

            // Inputs to CMSampleBufferCreate
            let timingInfo:[CMSampleTimingInfo] = [CMSampleTimingInfo(duration: duration, presentationTimeStamp: time, decodeTimeStamp: time)]
            let sampleSizes:[Int] = [CMBlockBufferGetDataLength(blockBuffer)]

            // Outputs from CMSampleBufferCreate
            var unmanagedSampleBuffer: CMSampleBuffer?

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
                &unmanagedSampleBuffer          // sBufOut: UnsafeMutablePointer<Unmanaged<CMSampleBuffer>?>
            )

            if result != 0 {
                error = makeOSStatusError(result, description:"CMSampleBufferCreate() failed")
                return nil
            }

            return unmanagedSampleBuffer
        }
        else {
            return nil
        }
    }

}

// MARK: -
