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

    public func processFragmentationUnit(fragmentationUnit:FragmentationUnit, inout error:ErrorType?) -> H264NALU? {
        switch fragmentationUnit.position {
            case .Start:
                fragmentationUnits = [fragmentationUnit]
                return nil
            case .Middle:
                fragmentationUnits.append(fragmentationUnit)
                return nil
            case .End:
                fragmentationUnits.append(fragmentationUnit)
                return processFragmentationUnits(fragmentationUnits, error:&error)
        }
    }

    private func processFragmentationUnits(var fragmentationUnits:[FragmentationUnit], inout error:ErrorType?) -> H264NALU? {

        // TODO: Deal with missing sequence numbers
        // TODO: Deal with wrapping of sequence number
        // TODO: check timestamps and subtypes are correct

        fragmentationUnits.sortInPlace {
            return $0.sequenceNumber < $1.sequenceNumber
        }

        let firstFragmentationUnit = fragmentationUnits.first!

        // Make sure we have a valid subtype
        if let _ = H264NALUType(rawValue: firstFragmentationUnit.subtype) {
            // Nothing to do
        }
        else {
            error = RTPError.unknownH264Type(firstFragmentationUnit.subtype)
            return nil
        }

        let header = H264NALU.headerForType(nal_ref_idc:firstFragmentationUnit.nal_ref_idc, type:firstFragmentationUnit.subtype)
        let headerData = DispatchData <Void> (value:header)

        // Concat the bodies.
        let bodyData = fragmentationUnits.reduce(DispatchData <Void> ()) {
            return $0 + $1.body
        }

        let data = headerData + bodyData

        let nalu = H264NALU(timestamp:firstFragmentationUnit.timestamp, data: data)

        assert(nalu.rawType == firstFragmentationUnit.subtype)

        return nalu
    }

}
