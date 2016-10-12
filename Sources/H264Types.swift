//
//  H264Types.swift
//  RTP Test
//
//  Created by Jonathan Wight on 6/30/15.
//  Copyright © 2015 3D Robotics Inc. All rights reserved.
//


import SwiftUtilities

public enum H264NALUType: UInt8 {
    case sliceNonIDR = 1 // P/B-Frame
    case sliceIDR = 5 // I-Frame
    case sps = 7 // "Sequence Parameter Set"
    case pps = 8 // "Picture Parameter Set"
}

// MARK: -

extension H264NALUType: CustomStringConvertible {
    public var description: String {
        switch self {
            case .sliceNonIDR:
                return "SliceNonIDR"
            case .sliceIDR:
                return "SliceIDR"
            case .sps:
                return "SPS"
            case .pps:
                return "PPS"
        }
    }
}

// MARK: -

public struct H264NALU {

    public let data: DispatchData <Void>
    public let body: DispatchData <Void>
    public let time: CMTime

    public fileprivate(set) var forbidden_zero_bit: Bool = false
    public fileprivate(set) var nal_ref_idc: UInt8 = 0
    public fileprivate(set) var rawType: UInt8 = 0

    public var type: H264NALUType? {
        return H264NALUType(rawValue: rawType)
    }

    static func headerForType(nal_ref_idc: UInt8, type: UInt8) -> UInt8 {
        var value: UInt8 = 0x0
        value = bitSet(value: value, range: 1..<3, flipped: true, newValue: nal_ref_idc)
        value = bitSet(value: value, range: 3..<8, flipped: true, newValue: type)
        return value
    }

    public init(time: CMTime, data: DispatchData <Void>) throws {
        assert(data.length > 0)

        self.time = time
        self.data = data

        let header = try data.subBuffer(startIndex: 0, count: 1)
        body = try data.inset(startInset: 1)

        header.createMap() {
            (_, header) -> Void in
            forbidden_zero_bit = bitRange(header, range: 0..<1) == 1 ? true : false
            nal_ref_idc = UInt8(bitRange(header, range: 1..<3))
            rawType = UInt8(bitRange(header, range: 3..<8))
        }
    }
}
