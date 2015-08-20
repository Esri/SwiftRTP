//
//  NetworkEndian.swift
//  SwiftIO
//
//  Created by Jonathan Wight on 8/10/15.
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


public extension UInt16 {
    init(networkEndian value:UInt16) {
        self = UInt16(bigEndian: value)
    }
    var networkEndian: UInt16 {
        return bigEndian
    }
}

public extension UInt32 {
    init(networkEndian value:UInt32) {
        self = UInt32(bigEndian: value)
    }
    var networkEndian: UInt32 {
        return bigEndian
    }
}

public extension UInt64 {
    init(networkEndian value:UInt64) {
        self = UInt64(bigEndian: value)
    }
    var networkEndian: UInt64 {
        return bigEndian
    }
}

public extension Int16 {
    init(networkEndian value:Int16) {
        self = Int16(bigEndian: value)
    }
    var networkEndian: Int16 {
        return bigEndian
    }
}

public extension Int32 {
    init(networkEndian value:Int32) {
        self = Int32(bigEndian: value)
    }
    var networkEndian: Int32 {
        return bigEndian
    }
}

public extension Int64 {
    init(networkEndian value:Int64) {
        self = Int64(bigEndian: value)
    }
    var networkEndian: Int64 {
        return bigEndian
    }
}