//
//  H264Processor.swift
//  RTP Test
//
//  Created by Jonathan Wight on 6/30/15.
//  Copyright © 2015 3D Robotics Inc. All rights reserved.
//

import CoreMedia

import SwiftUtilities

let H264ClockRate: Int32 = 90_000

public class H264Processor {

    public enum Output {
        case FormatDescription(CMFormatDescription)
        case SampleBuffer(CMSampleBuffer)
    }

    weak var context: RTPContextType!
    var lastParameterSet: H264ParameterSet?
    var currentParameterSet: H264ParameterSet = H264ParameterSet()

    public init(context: RTPContextType) {
        self.context = context
    }

    public func process(nalu: H264NALU) throws -> Output? {

        guard let type = nalu.type else {
            throw RTPError.UnknownH264Type(nalu.rawType)
        }

        switch type {
            case .SliceIDR, .SliceNonIDR:
                return try processVideoFrame(nalu)
            default:
                break
        }

        switch type {
            case .SPS:
                currentParameterSet.sps = nalu
                context.postEvent(RTPEvent.SPSReceived)
            case .PPS:
                currentParameterSet.pps = nalu
                context.postEvent(RTPEvent.PPSReceived)
            default:
                throw Error.Generic("Unhandled NALU type.")
        }

        guard currentParameterSet.isComplete == true else {
            return nil
        }

        let formatDescription = try currentParameterSet.toFormatDescription()

        if lastParameterSet != currentParameterSet {
            lastParameterSet = currentParameterSet
            currentParameterSet = H264ParameterSet()

            context.postEvent(RTPEvent.H264ParameterSetCycled)
        }

        return .FormatDescription(formatDescription)
    }

    public func processVideoFrame(nalu: H264NALU) throws -> Output {
        guard let lastParameterSet = lastParameterSet where lastParameterSet.isComplete == true else {
            throw RTPError.SkippedFrame("No formatDescription, skipping frame.")
        }

        let sampleBuffer = try naluToCMSampleBuffer(nalu, formatDescription: lastParameterSet.toFormatDescription())
        return .SampleBuffer(sampleBuffer)
    }

    func naluToCMSampleBuffer(nalu: H264NALU, formatDescription: CMFormatDescription) throws -> CMSampleBuffer {

        // Prepend the size of the data to the data as a 32-bit network endian uint. (keyword: "elementary stream")
        let headerValue = UInt32(nalu.data.length)
        let headerData = DispatchData <Void>(value: headerValue.bigEndian)
        let sizedData = headerData + nalu.data

        let blockBuffer = try sizedData.toCMBlockBuffer()

        // So what about STAP???? From CMSampleBufferCreate "Behavior is undefined if samples in a CMSampleBuffer (or even in multiple buffers in the same stream) have the same presentationTimeStamp"

        // Computer the duration and time
        let duration = kCMTimeInvalid // CMTimeMake(3000, H264ClockRate) // TODO: 1/30th of a second. Making this up.


        // Inputs to CMSampleBufferCreate
        let timingInfo: [CMSampleTimingInfo] = [CMSampleTimingInfo(duration: duration, presentationTimeStamp: nalu.time, decodeTimeStamp: nalu.time)]
        let sampleSizes: [Int] = [CMBlockBufferGetDataLength(blockBuffer)]

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
            throw makeOSStatusError(result, description: "CMSampleBufferCreate() failed")
        }

        CMSampleBufferSetDisplayImmediately(sampleBuffer)

        return sampleBuffer!
    }

}
