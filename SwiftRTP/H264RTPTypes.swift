//
//  H264RTPTypes.swift
//  RTP Test
//
//  Created by Jonathan Wight on 7/1/15.
//  Copyright © 2015 3D Robotics Inc. All rights reserved.
//

import SwiftUtilities

public enum H264RTPType: UInt8 {
    case STAP_A = 24
    case STAP_B = 25
    case MTAP16 = 26
    case MTAP24 = 27
    case FU_A = 28
    case FU_B = 29
}

public struct FragmentationUnit {

    public enum Position: UInt8 {
        case Start =  0b10
        case Middle = 0b00
        case End =    0b01
    }

    public let header:DispatchData <Void>
    public let body:DispatchData <Void>

    private(set) var position:Position = .Start
    private(set) var subtype:UInt8 = 0

    // From RTPPacket
    private(set) var time:CMTime
    private(set) var sequenceNumber:UInt16

    // From H264NALU
    private(set) var nal_ref_idc:UInt8 = 0

    public init(rtpPacket:RTPPacket, nalu:H264NALU) {

        let data = nalu.body

        header = data.subBuffer(startIndex: 0, count: 1)
        body = data.inset(startInset: 1)
        self.time = nalu.time
        self.sequenceNumber = rtpPacket.sequenceNumber
        self.nal_ref_idc = nalu.nal_ref_idc

        header.createMap() {
            (_, header) -> Void in

            let rawPosition = UInt8(bitRange(header, range:0..<2))
            position = Position(rawValue: rawPosition)!
            let reserved = bitRange(header, range:2..<3)
            assert(reserved == 0)
            subtype = UInt8(bitRange(header, range:3..<8))
        }
    }
}
