//
//  TCPChannel.swift
//  SwiftIO
//
//  Created by Jonathan Wight on 6/23/15.
//  Copyright (c) 2015 schwa.io. All rights reserved.
//

import Darwin

import SwiftRTP

// TODO: This is a very very very very early WIP

public class TCPChannel {

    public let address:Address
    public let port:UInt16
    public var errorHandler:(ErrorType -> Void)? = loggingErrorHandler

    private var resumed:Bool = false
    private var queue:dispatch_queue_t!
    private var socket:Int32!

    public init(address:Address, port:UInt16) {
        self.address = address
        self.port = port
    }

    public convenience init(hostname:String = "0.0.0.0", port:UInt16, family:ProtocolFamily? = nil) {
        var error: ErrorType?
        let addresses:[Address] = Address.addresses(hostname, `protocol`: .TCP, family: family, error: &error)!
        self.init(address:addresses[0], port:port)
    }

    public func resume(inout error:ErrorType?) -> Bool {
        debugLog?("Resuming")

        socket = Darwin.socket(PF_INET, SOCK_STREAM, IPPROTO_TCP)
        if socket < 0 {
            errorHandler?(Error.generic("socket() failed"))
            return false
        }

        var addr = address.to_sockaddr(port: port)

        let result = withUnsafePointer(&addr) {
            (ptr:UnsafePointer <sockaddr>) -> Int32 in
            return Darwin.connect(socket, ptr, socklen_t(sizeof(sockaddr)))
        }

        if result != 0 {
            cleanup()
            error = Error.posix(errno, "connect() failed")
            return false
        }

        queue = dispatch_queue_create("io.schwa.SwiftIO.TCP", DISPATCH_QUEUE_CONCURRENT)

        return true
    }

    public func cancel() {
    }

    internal func cleanup() {
        if let socket = self.socket {
            Darwin.close(socket)
        }
        self.socket = nil
        self.queue = nil
    }
}

// MARK: -

internal func loggingErrorHandler(error:ErrorType) {
    debugLog?("ERROR: \(error)")
}

internal func loggingWriteHandler(success:Bool, error:Error?) {
    if success {
        debugLog?("WRITE")
    }
    else {
        loggingErrorHandler(error!)
    }
}
