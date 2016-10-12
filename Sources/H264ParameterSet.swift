//
//  H264ParameterSet.swift
//  SwiftRTP
//
//  Created by Jonathan Wight on 9/17/15.
//  Copyright © 2015 schwa. All rights reserved.
//

import Foundation

import SwiftUtilities

public struct H264ParameterSet {
    public internal(set) var sps: H264NALU?
    public internal(set) var pps: H264NALU?

    public var isComplete: Bool {
        return sps != nil && pps != nil
    }

    func toFormatDescription() throws -> CMFormatDescription {

        guard isComplete == true else {
            throw SwiftUtilities.Error.generic("Incomplete parameter set (pps: \(pps != nil), sps: \(sps != nil))")
        }

        guard let spsData = sps?.data, let ppsData = pps?.data else {
            throw SwiftUtilities.Error.generic("No SPS & PPS.")
        }

        return try makeFormatDescription(sps: spsData, pps: ppsData)
    }

    func makeFormatDescription(sps sps: DispatchData <Void>, pps: DispatchData <Void>) throws -> CMFormatDescription {

        return try pps.createMap() {
            (_, ppsBuffer) in

            return try sps.createMap() {
                (_, spsBuffer) in

                let pointers: [UnsafePointer <UInt8>] = [
                    UnsafePointer <UInt8> (ppsBuffer.baseAddress),
                    UnsafePointer <UInt8> (spsBuffer.baseAddress),
                ]
                let sizes: [Int] = [
                    ppsBuffer.count,
                    spsBuffer.count,
                ]

                // Size of NALU length headers in AVCC/MPEG-4 format (can be 1, 2, or 4).
                let NALUnitHeaderLength: Int32 = 4

                var formatDescription: CMFormatDescription?
                let result = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault, pointers.count, pointers, sizes, NALUnitHeaderLength, &formatDescription)
                if result != 0 {
                    throw makeOSStatusError(result, description: "CMVideoFormatDescriptionCreateFromH264ParameterSets failed")
                }
                return formatDescription!
            }
        }
    }
}

// MARK: -

extension H264ParameterSet: Equatable {
}

public func == (lhs: H264ParameterSet, rhs: H264ParameterSet) -> Bool {
    return lhs.sps?.data == rhs.sps?.data && lhs.pps?.data == rhs.pps?.data
}
