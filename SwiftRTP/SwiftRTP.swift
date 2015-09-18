//
//  SwiftRTP.swift
//  SwiftRTP
//
//  Created by Jonathan Wight on 8/26/15.
//  Copyright (c) 2015 schwa. All rights reserved.
//

import Foundation

public class SwiftRTP {

    public static let sharedInstance = SwiftRTP()

    public var debugLog:((Any) -> Void)? = nil
//    public var debugLog:((Any) -> Void)? = { print($0) }
}

// MARK: -

public enum RTPEvent {
    case h264ParameterSetCycled
    case ppsReceived
    case spsReceived
    case naluProduced
    case badFragmentationUnit
    case errorInPipeline
    case h264FrameProduced
    case h264FrameSkipped
    case formatDescriptionProduced
    case sampleBufferProduced
    case packetReceived
}

