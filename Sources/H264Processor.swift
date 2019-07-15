//
//  H264Processor.swift
//  RTP Test
//
//  Created by Jonathan Wight on 6/30/15.
//  Copyright © 2015 3D Robotics Inc. All rights reserved.
//

import CoreMedia

import SwiftUtilities

open class H264Processor {

    public static let h264ClockRate: Int32 = 90_000

    public enum Output {
        case formatDescription(CMFormatDescription)
        case sampleBuffer(CMSampleBuffer)
    }

    weak var context: RTPContextType!
    var lastParameterSet: H264ParameterSet?
    var currentParameterSet: H264ParameterSet = H264ParameterSet()

    public init(context: RTPContextType) {
        self.context = context
    }

    open func process(_ nalu: H264NALU) throws -> Output? {

        guard let type = nalu.type else {
            throw RTPError.unknownH264Type(nalu.rawType)
        }

        switch type {
            case .sliceIDR, .sliceNonIDR:
                return try processVideoFrame(nalu)
            default:
                break
        }

        switch type {
            case .sps:
                currentParameterSet.sps = nalu
                context.postEvent(RTPEvent.spsReceived)
            case .pps:
                currentParameterSet.pps = nalu
                context.postEvent(RTPEvent.ppsReceived)
            default:
                throw SwiftUtilities.Error.generic("Unhandled NALU type.")
        }

        guard currentParameterSet.isComplete == true else {
            return nil
        }

        let formatDescription = try currentParameterSet.toFormatDescription()

        if lastParameterSet != currentParameterSet {
            lastParameterSet = currentParameterSet
            currentParameterSet = H264ParameterSet()

            context.postEvent(RTPEvent.h264ParameterSetCycled)
        }

        return .formatDescription(formatDescription)
    }

    open func processVideoFrame(_ nalu: H264NALU) throws -> Output {
        guard let lastParameterSet = lastParameterSet , lastParameterSet.isComplete == true else {
            throw RTPError.skippedFrame("No formatDescription, skipping frame.")
        }

        let sampleBuffer = try naluToCMSampleBuffer(nalu, formatDescription: lastParameterSet.toFormatDescription())
        return .sampleBuffer(sampleBuffer)
    }

    func naluToCMSampleBuffer(_ nalu: H264NALU, formatDescription: CMFormatDescription) throws -> CMSampleBuffer {

        // Prepend the size of the data to the data as a 32-bit network endian uint. (keyword: "elementary stream")
        let headerValue = UInt32(nalu.data.count)
        
        var sizedData = DispatchData(value: headerValue.bigEndian)
        sizedData.append(nalu.data)
        
        let blockBuffer = try sizedData.toCMBlockBuffer()

        // So what about STAP???? From CMSampleBufferCreate "Behavior is undefined if samples in a CMSampleBuffer (or even in multiple buffers in the same stream) have the same presentationTimeStamp"

        // Computer the duration and time
        let duration = CMTime.invalid // CMTimeMake(3000, H264ClockRate) // TODO: 1/30th of a second. Making this up.


        // Inputs to CMSampleBufferCreate
        let timingInfo: [CMSampleTimingInfo] = [CMSampleTimingInfo(duration: duration, presentationTimeStamp: nalu.time, decodeTimeStamp: nalu.time)]
        let sampleSizes: [Int] = [CMBlockBufferGetDataLength(blockBuffer)]

        // Outputs from CMSampleBufferCreate
        var sampleBuffer: CMSampleBuffer?

        let result = CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,            // allocator: CFAllocator?,
            dataBuffer: blockBuffer,                    // dataBuffer: CMBlockBuffer?,
            dataReady: true,                           // dataReady: Boolean,
            makeDataReadyCallback: nil,                            // makeDataReadyCallback: CMSampleBufferMakeDataReadyCallback?,
            refcon: nil,                            // makeDataReadyRefcon: UnsafeMutablePointer<Void>,
            formatDescription: formatDescription,              // formatDescription: CMFormatDescription?,
            sampleCount: 1,                              // numSamples: CMItemCount,
            sampleTimingEntryCount: timingInfo.count,               // numSampleTimingEntries: CMItemCount,
            sampleTimingArray: timingInfo,                     // sampleTimingArray: UnsafePointer<CMSampleTimingInfo>,
            sampleSizeEntryCount: sampleSizes.count,              // numSampleSizeEntries: CMItemCount,
            sampleSizeArray: sampleSizes,                    // sampleSizeArray: UnsafePointer<Int>,
            sampleBufferOut: &sampleBuffer                   // sBufOut: UnsafeMutablePointer<Unmanaged<CMSampleBuffer>?>
        )

        if result != 0 {
            throw makeOSStatusError(result, description: "CMSampleBufferCreate() failed")
        }

        CMSampleBufferSetDisplayImmediately(sampleBuffer)

        return sampleBuffer!
    }

}
