//
//  SwiftRTP.swift
//  SwiftRTP
//
//  Created by Jonathan Wight on 8/26/15.
//  Copyright (c) 2015 schwa. All rights reserved.
//

import Foundation

open class SwiftRTP {

    open static let sharedInstance = SwiftRTP()

    open var debugLog: ((Any) -> Void)? = nil
//    public var debugLog: ((Any) -> Void)? = { print($0) }
}

// MARK: -
