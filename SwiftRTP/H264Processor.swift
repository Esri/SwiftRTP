//
//  H264Processor.swift
//  RTP Test
//
//  Created by Jonathan Wight on 6/30/15.
//  Copyright © 2015 3D Robotics Inc. All rights reserved.
//

import CoreMedia

public class H264Processor {

    public enum Output {
        case formatDescription(CMFormatDescription)
        case sampleBuffer(CMSampleBuffer)
    }

    public internal(set) var lastSPS:H264NALU?
    public internal(set) var lastPPS:H264NALU?
    public internal(set) var firstTimestamp:UInt32?
    public var defaultFormatDescription:CMFormatDescription?
    public var lastFormatDescription:CMFormatDescription?

    public init() {
    }

    public func process(nalu:H264NALU, inout error:ErrorType?) -> Output? {

        if let type = nalu.type {
            switch type {
                case .SliceIDR, .SliceNonIDR:
                    return processVideoFrame(nalu, error:&error)
                case .SPS:
                    lastSPS = nalu
                case .PPS:
                    lastPPS = nalu
            }

            if let SPS = lastSPS, let PPS = lastPPS {
                if let formatDescription = makeFormatDescription(SPS, PPS, error:&error) {
                    self.lastFormatDescription = formatDescription
                    // TODO: Do we want to do this
                    lastSPS = nil
                    lastPPS = nil
                    return .formatDescription(formatDescription)
                }
            }

        }
        else {
            error = RTPError.unknownH264Type(nalu.rawType)
        }
        return nil
    }

    public func processVideoFrame(nalu:H264NALU, inout error:ErrorType?) -> Output? {
        if let formatDescription = lastFormatDescription {

            if let sampleBuffer = nalu.toCMSampleBuffer(formatDescription, error:&error) {
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

    func toCMSampleBuffer(formatDescription:CMFormatDescription, inout error:ErrorType?) -> CMSampleBuffer? {

        let headerValue = UInt32(data.length)
        let headerData = DispatchData <Void>(value:headerValue.bigEndian)
        let sizedData = headerData + data

        if let blockBuffer = sizedData.toCMBlockBuffer(&error) {

            let duration = CMTimeMake(1, 60)
            let clock = CMClockGetHostTimeClock()
            let time = CMClockGetTime(clock)
            let timingInfo:[CMSampleTimingInfo] = [CMSampleTimingInfo(duration: duration, presentationTimeStamp: time, decodeTimeStamp: time)]

            let sampleSizes:[Int] = [CMBlockBufferGetDataLength(blockBuffer)]

            var unmanagedSampleBuffer: Unmanaged <CMSampleBuffer>?

            let result = CMSampleBufferCreate(
                kCFAllocatorDefault,            // allocator: CFAllocator?,
                blockBuffer,                    // dataBuffer: CMBlockBuffer?,
                Boolean(1),                     // dataReady: Boolean,
                nil,                            // makeDataReadyCallback: CMSampleBufferMakeDataReadyCallback?,
                nil,                            // makeDataReadyRefcon: UnsafeMutablePointer<Void>,
                formatDescription,              // formatDescription: CMFormatDescription?,
                1,                              // numSamples: CMItemCount,
                timingInfo.count,             // numSampleTimingEntries: CMItemCount,
                timingInfo,                   // sampleTimingArray: UnsafePointer<CMSampleTimingInfo>,
    //            0,                              // numSampleTimingEntries: CMItemCount,
    //            nil,                            // sampleTimingArray: UnsafePointer<CMSampleTimingInfo>,
                sampleSizes.count,              // numSampleSizeEntries: CMItemCount,
                sampleSizes,                    // sampleSizeArray: UnsafePointer<Int>,
                &unmanagedSampleBuffer                   // sBufOut: UnsafeMutablePointer<Unmanaged<CMSampleBuffer>?>
            )

            if result != 0 {
                error = makeOSStatusError(result, description:"CMSampleBufferCreate() failed")
                return nil
            }

    //        CMSampleBufferSetDisplayImmediately(sampleBuffer)

            let sampleBuffer = unmanagedSampleBuffer?.takeRetainedValue()
            return sampleBuffer
        }
        else {
            return nil
        }
    }

}

// MARK: -
