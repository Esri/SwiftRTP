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

