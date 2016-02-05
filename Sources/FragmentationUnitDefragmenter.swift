//
//  FragmentationUnitDefragmenter.swift
//  RTP Test
//
//  Created by Jonathan Wight on 8/18/15.
//  Copyright © 2015 3D Robotics Inc. All rights reserved.
//

import SwiftUtilities

public class FragmentationUnitDefragmenter {

    weak var context: RTPContextType!
    public private(set) var fragmentationUnits: [FragmentationUnit] = []

    public init(context: RTPContextType) {
        self.context = context
    }

    public func processFragmentationUnit(fragmentationUnit: FragmentationUnit) throws -> H264NALU? {
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

    private func processFragmentationUnits(fragmentationUnits: [FragmentationUnit]) throws -> H264NALU {

        // TODO: check timestamps and subtypes are correct

        let fragmentationUnits = try reorderSequence(fragmentationUnits)

        let firstFragmentationUnit = fragmentationUnits.first!

        // Make sure we have a valid subtype
        guard let _ = H264NALUType(rawValue: firstFragmentationUnit.subtype) else {
            context.postEvent(.BadFragmentationUnit)
            throw RTPError.UnknownH264Type(firstFragmentationUnit.subtype)
        }

        let header = H264NALU.headerForType(nal_ref_idc: firstFragmentationUnit.nal_ref_idc, type: firstFragmentationUnit.subtype)
        let headerData = DispatchData <Void> (value: header)

        // Concat the bodies.
        let bodyData = fragmentationUnits.reduce(DispatchData <Void> ()) {
            return $0 + $1.body
        }

        let data = headerData + bodyData

        let nalu = try H264NALU(time: firstFragmentationUnit.time, data: data)

        assert(nalu.rawType == firstFragmentationUnit.subtype)

        return nalu
    }

    /// Reorder packets based on sequence number while handling sequence number wrap-around. Throws if there are gaps in the sequence.
    private func reorderSequence(input: [FragmentationUnit]) throws -> [FragmentationUnit] {

        // This should never happen - but if we do see it we're good.
        if input.count <= 1 {
            return input
        }

        // Everything else hinges on sorting the packets by sequence number.
        let sortedInput = input.sort() {
            return $0.sequenceNumber < $1.sequenceNumber
        }

        // We wrap around if the first packet has seq num 0 and last packet has seq num 65535
        let wrapsAround = sortedInput.first!.sequenceNumber == 0 && sortedInput.last!.sequenceNumber == UInt16.max

        var gapIndex: Int?
        var lastSequenceNumber: UInt16?

        // Look for gaps and the number of packets that are in the range before the gap.
        for (index, item) in sortedInput.enumerate() {
            if let lastSequenceNumber = lastSequenceNumber {
                // If the packets are in sequence the difference between sequence numbers should be 1...
                // But if the packets wrap around there should be exactly one (valid) gap.
                let delta = item.sequenceNumber - lastSequenceNumber
                if delta != 1 {
                    // If we don't wrap around _and_ there's a gap then there's a problem.
                    if wrapsAround == false {
                        context.postEvent(.BadFragmentationUnit)
                        throw RTPError.FragmentationUnitError("Fragmentation unit doesn't wrap but have found a gap in sequence numbers", sortedInput.map { return $0.sequenceNumber })
                    }
                    // If we do wrap around _and_ there's already a gap, another gap signifies a problem.
                    if gapIndex != nil {
                        context.postEvent(.BadFragmentationUnit)
                        throw RTPError.FragmentationUnitError("Fragmentation unit does wrap but have found more than one gap in sequence numbers", sortedInput.map { return $0.sequenceNumber })
                    }
                    gapIndex = index
                }
            }
            lastSequenceNumber = item.sequenceNumber
        }

        let result: [FragmentationUnit]

        if wrapsAround == true {
            guard let gapIndex = gapIndex else {
                preconditionFailure()
            }
            let start = sortedInput[gapIndex..<sortedInput.endIndex]
            let end = sortedInput[0..<gapIndex]
            result = Array <FragmentationUnit> (start + end)
//            print("WRAP AROUND")
//            print(result.map { return $0.sequenceNumber })
        }
        else {
            result = sortedInput
        }

        // Make sure first and last packets are actually start and end packets.
        // In theory we should make sure other packets are not start and end but that's guaranteed not to happen if we get here.
        guard result.first!.position == .Start && result.last!.position == .End else {
            context.postEvent(.BadFragmentationUnit)
            throw RTPError.FragmentationUnitError("First and last packets not start and end packets of a sequence", result.map { return $0.sequenceNumber })
        }

        return result
    }
}
