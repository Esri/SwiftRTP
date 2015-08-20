//
//  RTPUtilities.swift
//  RTP Test
//
//  Created by Jonathan Wight on 7/1/15.
//  Copyright © 2015 3D Robotics Inc. All rights reserved.
//

import CoreMedia

public enum RTPError: ErrorType {
    case unknownH264Type(UInt8)
    case unsupportedFeature(String)
    case skippedFrame(String)
    case generic(String)
    case posix(Int32,String)
}

extension RTPError: CustomStringConvertible {
    public var description: String {
        switch self {
            case .unknownH264Type(let type):
                return "Unknown H264 Type: \(type)"
            case .unsupportedFeature(let string):
                return "Unsupported Feature: \(string)"
            case .skippedFrame(let string):
                return "Skipping Frame: \(string)"
            case .generic(let string):
                return "\(string)"
            case .posix(let result, let string):
                return "\(result): \(string)"
        }
    }
}

