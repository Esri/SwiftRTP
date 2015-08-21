//
//  RTPProcessor.swift
//  RTP Test
//
//  Created by Jonathan Wight on 6/26/15.
//  Copyright © 2015 3D Robotics Inc. All rights reserved.
//

import AVFoundation
import CoreMedia

public class RTPProcessor {

    public private(set) var firstTimestamp:UInt32?
    var defragmenter = FragmentationUnitDefragmenter()

    public func process(data:DispatchData <Void>, inout error:ErrorType?) -> [H264NALU]? {

        let packet = RTPPacket(data: data)
        if firstTimestamp == nil {
            firstTimestamp = packet.timestamp
        }

        // TODO
        if packet.paddingFlag != false {
            error = RTPError.unsupportedFeature("RTP padding flag not supported (yet)")
            return nil
        }

        // TODO
        if packet.extensionFlag != false {
            error = RTPError.unsupportedFeature("RTP extension flag not supported (yet)")
            return nil
        }

        // TODO
        if packet.csrcCount != 0 {
            error = RTPError.unsupportedFeature("Non-zero CSRC not supported (yet)")
            return nil
        }

        let timestamp = Double(packet.timestamp) / 90_000

        let nalu = H264NALU(timestamp: timestamp, data: packet.body)

        if packet.payloadType != 96 {
            error = RTPError.unknownH264Type(nalu.rawType)
            return nil
        }

        if let type = H264RTPType(rawValue: nalu.rawType) {
            switch type {
                case .FU_A:
                    let fragmentationUnit = FragmentationUnit(rtpPacket:packet, nalu:nalu)
                    if let nalu = defragmenter.processFragmentationUnit(fragmentationUnit, error:&error) {
                        return [nalu]
                    }
                    else {
                        return nil
                    }
                case .STAP_A:
                    return processStapA(rtpPacket:packet, nalu:nalu, error:&error)
                default:
                    error = RTPError.unsupportedFeature("Unsupported H264 RTP type: \(type)")
                    return nil
            }
        }
        else {
            return [nalu]
        }
    }

    // TODO: This is NOT proven working code.
    func processStapA(# rtpPacket:RTPPacket, nalu:H264NALU, inout error:ErrorType?) -> [H264NALU]? {

        var nalus:[H264NALU] = []

        var data = nalu.body

        while data.length >= 2 {

            data.map() {
                (_, buffer) -> Void in

                let chunkLength = UInt16(networkEndian: UInt16(bitRange(buffer, range: 0..<16)))

                if Int(chunkLength) > data.length - sizeof(UInt16) {
                    error = RTPError.generic("STAP-A chunk length \(chunkLength) longer than all of STAP-A data \(data.length) - sizeof(UInt16)")
                }

                let subdata = data.subBuffer(startIndex: sizeof(UInt16), count:Int(chunkLength))

                let timestamp = Double(rtpPacket.timestamp) / 90_000

                let nalu = H264NALU(timestamp: timestamp, data: subdata)
                nalus.append(nalu)

                data = data.inset(startInset: sizeof(UInt16) + Int(chunkLength), endInset: 0)
            }
        }

        return nalus
    }

}

