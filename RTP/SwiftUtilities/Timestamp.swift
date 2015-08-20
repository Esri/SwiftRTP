//
//  Utilities.swift
//  BinaryTest
//
//  Created by Jonathan Wight on 6/24/15.
//
//  Copyright (c) 2014, Jonathan Wight
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  * Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
//  * Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
//  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
//  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//  OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


import Foundation

/**
 *  A wrapper around CFAbsoluteTime
 *
 *  CFAbsoluteTime is just typealias for a Double. By wrapping it in a struct we're able to extend it.
 */
public struct Timestamp {
    public let absoluteTime: CFAbsoluteTime

    public init() {
        absoluteTime = CFAbsoluteTimeGetCurrent()
    }

    public init(absoluteTime: CFAbsoluteTime) {
        self.absoluteTime = absoluteTime
    }
}

// MARK: -

extension Timestamp: Equatable {
}

public func ==(lhs: Timestamp, rhs: Timestamp) -> Bool {
    return lhs.absoluteTime == rhs.absoluteTime
}

// MARK: -

extension Timestamp: Comparable {
}

public func <(lhs: Timestamp, rhs: Timestamp) -> Bool {
    return lhs.absoluteTime < rhs.absoluteTime
}

// MARK: -

extension Timestamp: Hashable {
    public var hashValue: Int {
        return absoluteTime.hashValue
    }
}
