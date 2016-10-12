//
//  RTPTypes.swift
//  RTP Test
//
//  Created by Jonathan Wight on 6/26/15.
//  Copyright © 2015 3D Robotics Inc. All rights reserved.
//

import SwiftUtilities

public struct RTPPacket {

    public let header: DispatchData <Void>
    public private(set) var body: DispatchData <Void>! = nil
    public init(data: DispatchData <Void>) throws {
        header = try data.subBuffer(startIndex: 0, count: 12)

        try header.createMap() {
            (_, header) -> Void in

            version = UInt8(bitRange(header, range: 0...1))
            paddingFlag = bitRange(header, range: 2...2) == 1 ? true : false
            extensionFlag = bitRange(header, range: 3...3) == 1 ? true : false
            csrcCount = UInt8(bitRange(header, range: 4...7))
            markerFlag = bitRange(header, range: 8...8) == 1 ? true : false
            payloadType = UInt8(bitRange(header, range: 9...15))
            sequenceNumber = UInt16(bigEndian: UInt16(bitRange(header, range: 16...31)))
            timestamp = UInt32(bigEndian: UInt32(bitRange(header, range: 32...63)))
            ssrcIdentifier = UInt32(bigEndian: UInt32(bitRange(header, range: 64...95)))

            assert(paddingFlag == false)
            assert(extensionFlag == false)
            assert(csrcCount == 0)

            body = try data.inset(startInset: 12)

    public fileprivate(set) var version: UInt8 = 0
    public fileprivate(set) var paddingFlag: Bool = false
    public fileprivate(set) var extensionFlag: Bool = false
    public fileprivate(set) var csrcCount: UInt8 = 0
    public fileprivate(set) var markerFlag: Bool = false
    public fileprivate(set) var payloadType: UInt8 = 0
    public fileprivate(set) var sequenceNumber: UInt16 = 0
    public fileprivate(set) var timestamp: UInt32 = 0
    public fileprivate(set) var ssrcIdentifier: UInt32 = 0

        }
    }
}

extension RTPPacket: CustomStringConvertible {
    public var description: String {

        let flags = (paddingFlag ? "P" : "p") + (extensionFlag ? "E" : "e") + (markerFlag ? "M" : "m")
        let csrc = csrcCount > 1 ? "csrcCount: \(csrcCount), " : ""

        return "RTPPacket(version: \(version), flags: \(flags), \(csrc)payloadType: \(payloadType), sequenceNumber: \(sequenceNumber), timestamp: \(timestamp), ssrcIdentifier: \(ssrcIdentifier))"
    }
}
