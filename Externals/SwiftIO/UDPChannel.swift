//
//  UDPMavlinkReceiver.swift
//  SwiftIO
//
//  Created by Jonathan Wight on 4/22/15.
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


// MARK: -

/**
 *  A GCD based UDP listener.
 */
public class UDPChannel {

    public let address:Address
    public let port:UInt16
    public var readHandler:(Datagram -> Void)? = loggingReadHandler
    public var errorHandler:(ErrorType -> Void)? = loggingErrorHandler

    private var resumed:Bool = false
    private let queue:dispatch_queue_t = dispatch_queue_create("io.schwa.SwiftIO.UDP", DISPATCH_QUEUE_CONCURRENT)
    private var source:dispatch_source_t!
    private var socket:Int32!

    public init(address:Address, port:UInt16, readHandler:(Datagram -> Void)? = nil) {
        self.address = address
        self.port = port
        if let readHandler = readHandler {
            self.readHandler = readHandler
        }
    }

    public convenience init?(hostname:String = "0.0.0.0", port:UInt16, family:ProtocolFamily? = nil, readHandler:(Datagram -> Void)? = nil) {
        var error:ErrorType?
        let addresses:[Address] = Address.addresses(hostname, `protocol`: .UDP, family: family, error:&error)!
        // TODO
        self.init(address:addresses[0], port:port, readHandler:readHandler)
    }

    public func resume(inout error:ErrorType?) -> Bool {
        socket = Darwin.socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP)
        if socket < 0 {
            error = Error.generic("socket() failed")
            return false
        }

        var reuseSocketFlag:Int = 1
        let result = Darwin.setsockopt(socket, SOL_SOCKET, SO_REUSEADDR, &reuseSocketFlag, socklen_t(sizeof(Int)))
        if result != 0 {
            cleanup()
            error = Error.generic("setsockopt() failed")
            return false
        }

        source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, UInt(socket), 0, queue)
        if source == nil {
            cleanup()
            error = Error.generic("dispatch_source_create() failed")
            return false
        }

        dispatch_source_set_cancel_handler(source) {
            [weak self] in
            if let strong_self = self {
                debugLog?("Cancel handler")
                strong_self.cleanup()
                strong_self.resumed = false
            }
        }

        dispatch_source_set_event_handler(source) {
            [weak self] in
            if let strong_self = self {
                strong_self.read()
            }
        }

        dispatch_source_set_registration_handler(source) {
            [weak self] in
            if let strong_self = self {
                var address = strong_self.address.to_sockaddr(port:strong_self.port)
                let result = Darwin.bind(strong_self.socket, &address, socklen_t(sizeof(sockaddr)))
                if result != 0 {
                    strong_self.errorHandler?(Error.posix(result, "bind() failed"))
                    strong_self.cancel()
                    return
                }
                strong_self.resumed = true
                debugLog?("Listening on \(strong_self.address)")
            }
        }

        dispatch_resume(source)

        return true
    }

    public func cancel() {
        if resumed == true {
            assert(source != nil, "Cancel called with source = nil.")
            dispatch_source_cancel(source)
        }
    }

    public func send(data:NSData, address:Address! = nil, port:UInt16, writeHandler:((Bool,Error?) -> Void)? = loggingWriteHandler) {
        precondition(resumed == true, "Cannot send data on unresumed queue")

        dispatch_async(queue) {
            [weak self] in
            if let strong_self = self {
                debugLog?("Send")

                let address:Address = address ?? strong_self.address
                var addr = address.to_sockaddr(port: port)
                let result = Darwin.sendto(strong_self.socket, data.bytes, data.length, 0, &addr, socklen_t(addr.sa_len))
                if result == data.length {
                    writeHandler?(true, nil)
                }
                else if result < 0 {
                    writeHandler?(false, Error.generic("sendto() failed"))
                }
                if result < data.length {
                    writeHandler?(false, Error.generic("sendto() failed"))
                }
            }
        }
    }

    internal func read() {

        let data:NSMutableData! = NSMutableData(length: 4096)

        var addressData = Array <Int8> (count:Int(SOCK_MAXADDRLEN), repeatedValue:0)
        let (result, address, port) = addressData.withUnsafeMutableBufferPointer() {
            (inout ptr:UnsafeMutableBufferPointer <Int8>) -> (Int, Address?, UInt16?) in
            var addrlen:socklen_t = socklen_t(SOCK_MAXADDRLEN)
            let result = Darwin.recvfrom(socket, data.mutableBytes, data.length, 0, UnsafeMutablePointer<sockaddr> (ptr.baseAddress), &addrlen)
            if result < 0 {
                return (result, nil, nil)
            }

            let addr = UnsafeMutablePointer<sockaddr> (ptr.baseAddress).memory
            let address = Address(addr: addr)

            let port = UInt16(networkEndian: addr.port)
            return (result, address, port)
        }

        if result < 0 {
            let error = Error.generic("recvfrom() failed")
            errorHandler?(error)
        }

        data.length = result

        let dispatchData = DispatchData <Void> (start: data.bytes, count: data.length)

        let datagram = Datagram(from: (address!, port!), timestamp: Timestamp(), data: dispatchData)
        readHandler?(datagram)
    }

    internal func cleanup() {
        if let socket = self.socket {
            Darwin.close(socket)
        }
        self.socket = nil
        self.source = nil
    }
}
