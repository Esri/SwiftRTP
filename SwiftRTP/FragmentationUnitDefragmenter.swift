//
//  FragmentationUnitDefragmenter.swift
//  RTP Test
//
//  Created by Jonathan Wight on 8/18/15.
//  Copyright © 2015 3D Robotics Inc. All rights reserved.
//

import SwiftUtilities

public class FragmentationUnitDefragmenter {

    public private(set) var fragmentationUnits: [FragmentationUnit] = []

    public func processFragmentationUnit(fragmentationUnit:FragmentationUnit) throws -> H264NALU? {
        switch fragmentationUnit.position {
            case .Start:
                fragmentationUnits = [fragmentationUnit]
                return nil
            case .Middle:
                fragmentationUnits.append(fragmentationUnit)
                return nil
            case .End:
                fragmentationUnits.append(fragmentationUnit)
                return try processFragmentationUnits(fragmentationUnits)
        }
    }

    private func processFragmentationUnits(var fragmentationUnits:[FragmentationUnit]) throws -> H264NALU {

        // TODO: Deal with missing sequence numbers
        // TODO: Deal with wrapping of sequence number
        // TODO: check timestamps and subtypes are correct

        fragmentationUnits.sortInPlace {
            return $0.sequenceNumber < $1.sequenceNumber
        }

        let firstFragmentationUnit = fragmentationUnits.first!

        // Make sure we have a valid subtype
        guard let _ = H264NALUType(rawValue: firstFragmentationUnit.subtype) else {
            throw RTPError.unknownH264Type(firstFragmentationUnit.subtype)
        }

        let header = H264NALU.headerForType(nal_ref_idc:firstFragmentationUnit.nal_ref_idc, type:firstFragmentationUnit.subtype)
        let headerData = DispatchData <Void> (value:header)

        // Concat the bodies.
        let bodyData = fragmentationUnits.reduce(DispatchData <Void> ()) {
            return $0 + $1.body
        }

        let data = headerData + bodyData

        let nalu = H264NALU(time:firstFragmentationUnit.time, data: data)

        assert(nalu.rawType == firstFragmentationUnit.subtype)

        return nalu
    }

}
