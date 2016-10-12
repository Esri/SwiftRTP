//
//  H264RTPTypes.swift
//  RTP Test
//
//  Created by Jonathan Wight on 7/1/15.
//  Copyright © 2015 3D Robotics Inc. All rights reserved.
//

import SwiftUtilities

public enum H264RTPType: UInt8 {
    case stap_A = 24
    case stap_B = 25
    case mtap16 = 26
    case mtap24 = 27
    case fu_A = 28
    case fu_B = 29
}

public struct FragmentationUnit {

    public enum Position: UInt8 {
        case start =  0b10
        case middle = 0b00
        case end =    0b01
    }

    public let header: DispatchData <Void>
    public let body: DispatchData <Void>

    fileprivate(set) var position: Position = .start
    fileprivate(set) var subtype: UInt8 = 0

    // From RTPPacket
    fileprivate(set) var time: CMTime
    fileprivate(set) var sequenceNumber: UInt16

    // From H264NALU
    fileprivate(set) var nal_ref_idc: UInt8 = 0

    public init(rtpPacket: RTPPacket, nalu: H264NALU) throws {

        let data = nalu.body

        header = try data.subBuffer(startIndex: 0, count: 1)
        body = try data.inset(startInset: 1)
        self.time = nalu.time
        self.sequenceNumber = rtpPacket.sequenceNumber
        self.nal_ref_idc = nalu.nal_ref_idc

        header.createMap() {
            (_, header) -> Void in

            let rawPosition = UInt8(bitRange(header, range: 0..<2))
            position = Position(rawValue: rawPosition)!
            let reserved = bitRange(header, range: 2..<3)
            assert(reserved == 0)
            subtype = UInt8(bitRange(header, range: 3..<8))
        }
    }
}
