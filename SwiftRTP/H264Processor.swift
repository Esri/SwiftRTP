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
            let headerValue = UInt32(nalu.data.length)
            let headerData = DispatchData <Void>(value:headerValue.bigEndian)
            let data = headerData + nalu.data

            if let sampleBuffer = data.toCMSampleBuffer(formatDescription, error:&error) {
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

public extension DispatchData {

    func toCMBlockBuffer(inout error:ErrorType?) -> CMBlockBuffer? {

        let blockBuffer = map() {
            (data, buffer) -> CMBlockBuffer? in

            var data:dispatch_data_t? = data.data

            var source = CMBlockBufferCustomBlockSource()
            MakeBlockBufferCustomBlockSource(&source) {
                data = nil
                return
            }

            var unmanagedBlockBuffer:Unmanaged <CMBlockBuffer>?
            let result = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, UnsafeMutablePointer <Void> (buffer.baseAddress), buffer.length, kCFAllocatorNull, &source, 0, buffer.length, 0, &unmanagedBlockBuffer)
            if Int(result) != kCMBlockBufferNoErr {
                error = Error.todo
                return nil
            }
            let blockBuffer = unmanagedBlockBuffer?.takeRetainedValue()

            assert(CMBlockBufferGetDataLength(blockBuffer!) == buffer.count)
            return blockBuffer
        }
        return blockBuffer
    }

    func toCMSampleBuffer(formatDescription:CMFormatDescription, inout error:ErrorType?) -> CMSampleBuffer? {

        if let blockBuffer = toCMBlockBuffer(&error) {

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

public func makeFormatDescription(SPS:H264NALU, PPS:H264NALU, inout # error:ErrorType?) -> CMFormatDescription? {
    return makeFormatDescription(SPS.data, PPS.data, error: &error)
}

public func makeFormatDescription(SPS:DispatchData <Void>, PPS:DispatchData <Void>, inout # error:ErrorType?) -> CMFormatDescription? {

    return PPS.map() {
        (_, PPSBuffer) in

        return SPS.map() {
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

            var unmanagedFormatDescription: Unmanaged <CMFormatDescription>?
            let result = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault, pointers.count, pointers, sizes, NALUnitHeaderLength, &unmanagedFormatDescription)
            if result != 0 {
                error = makeOSStatusError(result, description: "CMVideoFormatDescriptionCreateFromH264ParameterSets failed")
            }
            var formatDescription = unmanagedFormatDescription?.takeRetainedValue()
            return formatDescription
        }
    }
}
