//
//  RTPTypes.swift
//  RTP Test
//
//  Created by Jonathan Wight on 6/26/15.
//  Copyright © 2015 3D Robotics Inc. All rights reserved.
//

import SwiftUtilities

public struct RTPPacket {

    public let header: DispatchData 
    public fileprivate(set) var body: DispatchData

    public fileprivate(set) var version: UInt8 = 0
    public fileprivate(set) var paddingFlag: Bool = false
    public fileprivate(set) var extensionFlag: Bool = false
    public fileprivate(set) var csrcCount: UInt8 = 0
    public fileprivate(set) var markerFlag: Bool = false
    public fileprivate(set) var payloadType: UInt8 = 0
    public fileprivate(set) var sequenceNumber: UInt16 = 0
    public fileprivate(set) var timestamp: UInt32 = 0
    public fileprivate(set) var ssrcIdentifier: UInt32 = 0

    public init(data: DispatchData ) throws {
        header = data.subdata(in:0..<12)
        
        version = header.withUnsafeBuffer { (buffer: UnsafeBufferPointer<UInt8>) -> UInt8 in
            return UInt8(bitRange(buffer: buffer, range: Range(0...1)))
        }
        
        paddingFlag = header.withUnsafeBuffer { (buffer: UnsafeBufferPointer<UInt8>) -> UInt8 in
            return UInt8(bitRange(buffer: buffer, range: Range(2...2)))
            } == 1 ? true : false
        
        extensionFlag = header.withUnsafeBuffer { (buffer: UnsafeBufferPointer<UInt8>) -> UInt8 in
            return UInt8(bitRange(buffer: buffer, range: Range(3...3)))
            } == 1 ? true : false
        
        csrcCount = header.withUnsafeBuffer { (buffer: UnsafeBufferPointer<UInt8>) -> UInt8 in
            return UInt8(bitRange(buffer: buffer, range: Range(4...7)))
        }
        
        markerFlag = header.withUnsafeBuffer { (buffer: UnsafeBufferPointer<UInt8>) -> UInt8 in
            return UInt8(bitRange(buffer: buffer, range: Range(8...8)))
            } == 1 ? true : false
        
        payloadType = header.withUnsafeBuffer { (buffer: UnsafeBufferPointer<UInt8>) -> UInt8 in
            return UInt8(bitRange(buffer: buffer, range: Range(9...15)))
        }
        
        sequenceNumber = header.withUnsafeBuffer { (buffer: UnsafeBufferPointer<UInt16>) -> UInt16 in
            return UInt16(bitRange(buffer: buffer, range: Range(16...31))).bigEndian
        }
        
        timestamp = header.withUnsafeBuffer { (buffer: UnsafeBufferPointer<UInt32>) -> UInt32 in
            return UInt32(bitRange(buffer: buffer, range: Range(32...63))).bigEndian
        }
        
        ssrcIdentifier = header.withUnsafeBuffer { (buffer: UnsafeBufferPointer<UInt32>) -> UInt32 in
            return UInt32(bitRange(buffer: buffer, range: Range(64...95))).bigEndian
        }
        
        body = data.subdata(in: 12..<data.endIndex)
        
        assert(paddingFlag == false)
        assert(extensionFlag == false)
        assert(csrcCount == 0)
    }
}

extension RTPPacket: CustomStringConvertible {
    public var description: String {

        let flags = (paddingFlag ? "P" : "p") + (extensionFlag ? "E" : "e") + (markerFlag ? "M" : "m")
        let csrc = csrcCount > 1 ? "csrcCount: \(csrcCount), " : ""

        return "RTPPacket(version: \(version), flags: \(flags), \(csrc)payloadType: \(payloadType), sequenceNumber: \(sequenceNumber), timestamp: \(timestamp), ssrcIdentifier: \(ssrcIdentifier))"
    }
}
