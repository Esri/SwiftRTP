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

    public let header: DispatchData 
    public let body: DispatchData 

    fileprivate(set) var position: Position = .start
    fileprivate(set) var subtype: UInt8 = 0

    // From RTPPacket
    fileprivate(set) var time: CMTime
    fileprivate(set) var sequenceNumber: UInt16

    // From H264NALU
    fileprivate(set) var nal_ref_idc: UInt8 = 0

    public init(rtpPacket: RTPPacket, nalu: H264NALU) throws {

        let data = nalu.body

        header = data.subdata(in: 0..<1)
        guard !header.isEmpty else {
            throw DataError.empty
        }
        
        body = data.subdata(in: 1..<data.endIndex)
        
        self.time = nalu.time
        self.sequenceNumber = rtpPacket.sequenceNumber
        self.nal_ref_idc = nalu.nal_ref_idc

        position = header.withUnsafeBuffer { (buffer: UnsafeBufferPointer<UInt8>) -> Position in
            let rawPosition = UInt8(bitRange(buffer: buffer, range: Range(0..<2)))
            return Position(rawValue: rawPosition)!
        }
        
        let reserved = header.withUnsafeBuffer { (buffer: UnsafeBufferPointer<UInt8>) -> UIntMax in
            return bitRange(buffer: buffer, range: Range(2..<3))
        }
        assert(reserved == 0)
        
        subtype = header.withUnsafeBuffer { (buffer: UnsafeBufferPointer<UInt8>) -> UInt8 in
            return UInt8(bitRange(buffer: buffer, range: Range(3..<8)))
        }
    }
}
