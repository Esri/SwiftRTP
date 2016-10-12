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

open class RTPProcessor {

    weak var context: RTPContextType!
    let defragmenter: FragmentationUnitDefragmenter

    init(context: RTPContextType) {
        self.context = context

        defragmenter = FragmentationUnitDefragmenter(context: context)
    }

    open func process(_ data: DispatchData ) throws -> [H264NALU]? {

        let packet = try RTPPacket(data: data)

        SwiftRTP.sharedInstance.debugLog?(String(describing: packet))

        let time = CMTimeMake(Int64(packet.timestamp), H264Processor.h264ClockRate)

        if packet.paddingFlag != false {
            throw RTPError.unsupportedFeature("RTP padding flag not supported (yet)")
        }

        if packet.extensionFlag != false {
            throw RTPError.unsupportedFeature("RTP extension flag not supported (yet)")
        }

        if packet.csrcCount != 0 {
            throw RTPError.unsupportedFeature("Non-zero CSRC not supported (yet)")
        }

        let nalu = try H264NALU(time: time, data: packet.body)

        if packet.payloadType != 96 {
            throw RTPError.unknownH264Type(nalu.rawType)
        }

        if let type = H264RTPType(rawValue: nalu.rawType) {
            switch type {
                case .fu_A:
                    let fragmentationUnit = try FragmentationUnit(rtpPacket: packet, nalu: nalu)
                    guard let nalu = try defragmenter.processFragmentationUnit(fragmentationUnit) else {
                        return nil
                    }
                    return [nalu]
                case .stap_A:
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
    func processStapA(rtpPacket: RTPPacket, nalu: H264NALU) throws -> [H264NALU]? {

        var nalus: [H264NALU] = []

        var data = nalu.body
        
        while data.count >= 2 {
            let chunkLength = data.withUnsafeBuffer { (buffer: UnsafeBufferPointer<UInt16>) -> UInt16 in
                return UInt16(networkEndian: UInt16(bitRange(buffer: buffer, range: 0..<16)))
            }
            
            let sizeOfUInt16 = MemoryLayout<UInt16>.size
            if Int(chunkLength) > data.count - sizeOfUInt16 {
                throw SwiftUtilities.Error.generic("STAP-A chunk length \(chunkLength) longer than all of STAP-A data \(data.count) - sizeof(UInt16)")
            }
            
            let subdata = data.subdata(in: sizeOfUInt16..<Int(chunkLength))
            let nalu = try H264NALU(time: nalu.time, data: subdata)
            nalus.append(nalu)
            
            data = data.subdata(in: sizeOfUInt16 + Int(chunkLength)..<data.endIndex)
        }

        return nalus
    }
}
