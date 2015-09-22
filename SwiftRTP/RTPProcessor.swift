//
//  RTPProcessor.swift
//  RTP Test
//
//  Created by Jonathan Wight on 6/26/15.
//  Copyright © 2015 3D Robotics Inc. All rights reserved.
//

import AVFoundation
import CoreMedia

import SwiftUtilities

public class RTPProcessor {

    var stream:RTPStream!
    var defragmenter = FragmentationUnitDefragmenter()

    public func process(data:DispatchData <Void>) throws -> [H264NALU]? {

        let packet = RTPPacket(data: data)

        SwiftRTP.sharedInstance.debugLog?(String(packet))

        if stream == nil {
            stream = RTPStream(ssrcIdentifier: packet.ssrcIdentifier)
        }

        if stream.ssrcIdentifier != packet.ssrcIdentifier {
            SwiftRTP.sharedInstance.debugLog?(String(RTPError.streamReset))
            stream = RTPStream(ssrcIdentifier: packet.ssrcIdentifier)
        }

        let time = try stream.clock.processTimestamp(packet.timestamp)

        if packet.paddingFlag != false {
            throw RTPError.unsupportedFeature("RTP padding flag not supported (yet)")
        }

        if packet.extensionFlag != false {
            throw RTPError.unsupportedFeature("RTP extension flag not supported (yet)")
        }

        if packet.csrcCount != 0 {
            throw RTPError.unsupportedFeature("Non-zero CSRC not supported (yet)")
        }

        let nalu = H264NALU(time: time, data: packet.body)

        if packet.payloadType != 96 {
            throw RTPError.unknownH264Type(nalu.rawType)
        }

        if let type = H264RTPType(rawValue: nalu.rawType) {
            switch type {
                case .FU_A:
                    let fragmentationUnit = FragmentationUnit(rtpPacket:packet, nalu:nalu)
                    guard let nalu = try defragmenter.processFragmentationUnit(fragmentationUnit) else {
                        return nil
                    }
                    return [nalu]
                case .STAP_A:
                    return try processStapA(rtpPacket:packet, nalu:nalu)
                default:
                    throw RTPError.unsupportedFeature("Unsupported H264 RTP type: \(type)")
            }
        }
        else {
            return [nalu]
        }
    }

    // TODO: This is NOT proven working code.
    func processStapA(rtpPacket rtpPacket:RTPPacket, nalu:H264NALU) throws -> [H264NALU]? {

        var nalus:[H264NALU] = []

        var data = nalu.body

        while data.length >= 2 {

            try data.createMap() {
                (_, buffer) -> Void in

                let chunkLength = UInt16(networkEndian: UInt16(bitRange(buffer, range: 0..<16)))

                if Int(chunkLength) > data.length - sizeof(UInt16) {
                    throw SwiftUtilities.Error.generic("STAP-A chunk length \(chunkLength) longer than all of STAP-A data \(data.length) - sizeof(UInt16)")
                }

                let subdata = data.subBuffer(startIndex: sizeof(UInt16), count:Int(chunkLength))

                let nalu = H264NALU(time: nalu.time, data: subdata)
                nalus.append(nalu)

                data = data.inset(startInset: sizeof(UInt16) + Int(chunkLength), endInset: 0)
            }
        }

        return nalus
    }

}

// MARK: -

class RTPStream {
    var ssrcIdentifier: UInt32
    var clock = RTPClock()

    init(ssrcIdentifier: UInt32) {
        self.ssrcIdentifier = ssrcIdentifier
    }
}

// MARK: -

class RTPClock {
    var firstTimestamp: UInt32? = nil
    var lastTimestamp: UInt32? = nil
    var lastClock: CFAbsoluteTime? = nil
    var maxDiff: Double = 0.0
    var totalDiff: Double = 0.0
    var count: Int = 0
    var offset = kCMTimeZero

    func processTimestamp(timestamp:UInt32) throws -> CMTime {

        count++

        let clock = CFAbsoluteTimeGetCurrent()

        defer {
            lastTimestamp = timestamp
            lastClock = clock
        }

        if firstTimestamp == nil {
            firstTimestamp = timestamp
        }

        guard let firstTimestamp = firstTimestamp else {
            fatalError()
        }

        if let lastClock = lastClock, let lastTimestamp = lastTimestamp {
            let deltaTimestamp = Double(Int64(timestamp) - Int64(lastTimestamp)) / 90_000
            let deltaClock = clock - lastClock
            let diff = abs(deltaTimestamp - deltaClock)

            totalDiff += diff
            if diff > maxDiff {
                maxDiff = diff
            }
//            SwiftRTP.sharedInstance.debugLog?((totalDiff, maxDiff))
        }

        let deltaTimestamp = timestamp - firstTimestamp
        let time = CMTimeAdd(offset, CMTimeMake(Int64(deltaTimestamp), H264ClockRate))

        return time
    }
}

//MARK: -

public struct RTPStatistics {
    public var magic:Int = 0
    public var lastUpdated: CFAbsoluteTime? = nil
    public var packetsReceived: Int = 0
    public var nalusProduced: Int = 0
    public var h264FramesProduced: Int = 0
    public var formatDescriptionsProduced: Int = 0
    public var sampleBuffersProduced: Int = 0
    public var lastH264FrameProduced: CFAbsoluteTime? = nil
    public var errorsProduced: Int = 0
    public var h264FramesSkipped: Int = 0
    public var badSequenceErrors: Int = 0
}
