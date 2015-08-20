//
//  Inet+Utilities.swift
//  SwiftIO
//
//  Created by Jonathan Wight on 5/20/15.
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


import Darwin
import Foundation

// MARK: in_addr extensions

extension in_addr: Equatable {
}

public func ==(lhs: in_addr, rhs: in_addr) -> Bool {
    return bitwiseEquality(lhs, rhs)
}

// MARK: in6_addr extensions

extension in6_addr: Equatable {
}

public func ==(lhs: in6_addr, rhs: in6_addr) -> Bool {
    return bitwiseEquality(lhs, rhs)
}

// MARK: -

extension sockaddr {

    func to_sockaddr_in() -> sockaddr_in {
        assert(sa_family == sa_family_t(AF_INET))
        assert(Int(sa_len) == sizeof(sockaddr_in))
        var copy = self
        return withUnsafePointer(&copy) {
            (ptr:UnsafePointer <sockaddr>) -> sockaddr_in in
            let ptr = UnsafePointer <sockaddr_in> (ptr)
            return ptr.memory
        }
    }

    func to_sockaddr_in6() -> sockaddr_in6 {
        assert(sa_family == sa_family_t(AF_INET6))
        assert(Int(sa_len) == sizeof(sockaddr_in6))
        var copy = self
        return withUnsafePointer(&copy) {
            (ptr:UnsafePointer <sockaddr>) -> sockaddr_in6 in
            let ptr = UnsafePointer <sockaddr_in6> (ptr)
            return ptr.memory
        }
    }

    /// Still in network endian.
    var port:UInt16 {
        switch self.sa_family {
            case sa_family_t(AF_INET):
                let addr = to_sockaddr_in()
                return addr.sin_port
            case sa_family_t(AF_INET6):
                let addr = to_sockaddr_in6()
                return addr.sin6_port
            default:
                preconditionFailure()
        }
    }
}

// MARK: sockaddr_in extensions

extension sockaddr_in {

    init(sin_family: sa_family_t, sin_port: in_port_t, sin_addr: in_addr) {
        self.sin_len = __uint8_t(sizeof(sockaddr_in))
        self.sin_family = sin_family
        self.sin_port = sin_port
        self.sin_addr = sin_addr
        self.sin_zero = (Int8(0), Int8(0), Int8(0), Int8(0), Int8(0), Int8(0), Int8(0), Int8(0))
    }

    func to_sockaddr() -> sockaddr {
        var copy = self
        return withUnsafePointer(&copy) {
            (ptr:UnsafePointer <sockaddr_in>) -> sockaddr in
            let ptr = UnsafePointer <sockaddr> (ptr)
            return ptr.memory
        }
    }
}

// MARK: sockaddr_in6 extensions

extension sockaddr_in6 {

    init(sin6_family: sa_family_t, sin6_port: in_port_t, sin6_addr: in6_addr) {
        self.sin6_len = __uint8_t(sizeof(sockaddr_in6))
        self.sin6_family = sin6_family
        self.sin6_port = sin6_port
        self.sin6_flowinfo = 0
        self.sin6_addr = sin6_addr
        self.sin6_scope_id = 0
    }

    func to_sockaddr() -> sockaddr {
        var copy = self
        return withUnsafePointer(&copy) {
            (ptr:UnsafePointer <sockaddr_in6>) -> sockaddr in
            let ptr = UnsafePointer <sockaddr> (ptr)
            return ptr.memory
        }
    }
}

// MARK: Swift wrapper functions for useful (but fiddly) POSIX network functions

public func inet_ntop(# addressFamily:Int32, # address:UnsafePointer <Void>, inout # error:ErrorType?) -> String? {
    var buffer = Array <Int8> (count: Int(INET6_ADDRSTRLEN) + 1, repeatedValue: 0)
    return buffer.withUnsafeMutableBufferPointer() {
        (inout outputBuffer:UnsafeMutableBufferPointer <Int8>) -> String in
        let result = inet_ntop(addressFamily, address, outputBuffer.baseAddress, socklen_t(INET6_ADDRSTRLEN))
        return String(CString: result, encoding: NSASCIIStringEncoding)!
    }
}

// MARK: -

public func getaddrinfo(hostname:String, # service:String, # hints:addrinfo, # block:UnsafePointer<addrinfo> -> Bool) -> Int32 {
    var hints = hints
    var info = UnsafeMutablePointer<addrinfo>()
    let result = hostname.withCString() {
        (hostnameBuffer:UnsafePointer <Int8>) -> Int32 in
        return service.withCString() {
            (serviceBuffer:UnsafePointer <Int8>) -> Int32 in
            return getaddrinfo(hostnameBuffer, serviceBuffer, &hints, &info)
        }
    }
    if result != 0 {
        return result
    }

    var current = info
    while current != nil {
        if block(current) == false {
            break
        }
        current = current.memory.ai_next
    }
    freeaddrinfo(info)

    return result
}
