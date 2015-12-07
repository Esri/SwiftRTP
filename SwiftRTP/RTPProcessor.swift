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

    weak var context: RTPContextType!
    let defragmenter: FragmentationUnitDefragmenter

    init(context: RTPContextType) {
        self.context = context

        defragmenter = FragmentationUnitDefragmenter(context: context)
    }

    public func process(data: DispatchData <Void>) throws -> [H264NALU]? {

        let packet = RTPPacket(data: data)

        SwiftRTP.sharedInstance.debugLog?(String(packet))

        let time = CMTimeMake(Int64(packet.timestamp), H264ClockRate)

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
                    let fragmentationUnit = FragmentationUnit(rtpPacket: packet, nalu: nalu)
                    guard let nalu = try defragmenter.processFragmentationUnit(fragmentationUnit) else {
                        return nil
                    }
                    return [nalu]
                case .STAP_A:
                    return try processStapA(rtpPacket: packet, nalu: nalu)
                default:
                    throw RTPError.unsupportedFeature("Unsupported H264 RTP type: \(type)")
            }
        }
        else {
            return [nalu]
        }
    }

    // TODO: This is NOT proven working code.
    func processStapA(rtpPacket rtpPacket: RTPPacket, nalu: H264NALU) throws -> [H264NALU]? {

        var nalus: [H264NALU] = []

        var data = nalu.body

        while data.length >= 2 {

            try data.createMap() {
                (_, buffer) -> Void in

                let chunkLength = UInt16(networkEndian: UInt16(bitRange(buffer, range: 0..<16)))

                if Int(chunkLength) > data.length - sizeof(UInt16) {
                    throw SwiftUtilities.Error.Generic("STAP-A chunk length \(chunkLength) longer than all of STAP-A data \(data.length) - sizeof(UInt16)")
                }

                let subdata = data.subBuffer(startIndex: sizeof(UInt16), count: Int(chunkLength))

                let nalu = H264NALU(time: nalu.time, data: subdata)
                nalus.append(nalu)

                data = data.inset(startInset: sizeof(UInt16) + Int(chunkLength), endInset: 0)
            }
        }

        return nalus
    }
}
