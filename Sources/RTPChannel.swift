//
//  RTPChannel.swift
//  RTP Test
//
//  Created by Jonathan Wight on 6/30/15.
//  Copyright © 2015 3D Robotics Inc. All rights reserved.
//

import CoreMedia

#if os(iOS)
import UIKit
#endif

import SwiftUtilities
import SwiftIO

public protocol RTPContextType: AnyObject {
    func postEvent(_ event: RTPEvent)
}

open class RTPChannel {

    open fileprivate(set) var rtpProcessor: RTPProcessor!
    open fileprivate(set) var h264Processor: H264Processor!
    open fileprivate(set) var udpChannel: UDPChannel!
    open fileprivate(set) var resumed = false
#if os(iOS)
    fileprivate var backgroundObserver: AnyObject?
    fileprivate var foregroundObserver: AnyObject?
#endif
    fileprivate var context: RTPContext! // TODO; Make let
    fileprivate let queue = DispatchQueue(label: "SwiftRTP.RTPChannel", qos: DispatchQoS.userInteractive, attributes: [], target: nil)
    
    open var handler: ((H264Processor.Output) throws -> Void)? {
        willSet {
            assert(resumed == false, "It is undefined to set properties while channel is resumed.")
        }
    }
    open var errorHandler: ((Swift.Error) -> Void)? {
        willSet {
            assert(resumed == false, "It is undefined to set properties while channel is resumed.")
        }
    }
    open var eventHandler: ((RTPEvent) -> Void)? {
        get {
            return context.eventHandler
        }
        set {
            assert(resumed == false, "It is undefined to set properties while channel is resumed.")
            context.eventHandler = newValue
        }
    }
    public init(port: UInt16) throws {

        context = try RTPContext()
        rtpProcessor = RTPProcessor(context: context)
        h264Processor = H264Processor(context: context)

#if os(iOS)
        backgroundObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationDidEnterBackground, object: nil, queue: nil) {
            [weak self] (notification) in
            self?.cancel()
        }
        foregroundObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationWillEnterForeground, object: nil, queue: nil) {
            [weak self] (notification) in
            self?.resume()
        }
#endif

        let address = try Address(address: "0.0.0.0", port: port)

        udpChannel = UDPChannel(label: "RTP", address: address, qos: DispatchQoS.userInteractive) {
            [weak self] (datagram) in

            guard let strong_self = self else {
                return
            }

            strong_self.queue.async {
                strong_self.processDatagram(datagram)
            }
        }
    }

    deinit {
#if os(iOS)
        if let backgroundObserver = backgroundObserver {
            NotificationCenter.default.removeObserver(backgroundObserver)
        }
        if let foregroundObserver = foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
        }
#endif
    }

    open func resume() {
        queue.sync {
            [weak self] in

            guard let strong_self = self else {
                return
            }

            if strong_self.resumed == true {
                return
            }
            do {
                try strong_self.udpChannel.resume()
                strong_self.resumed = true
            }
            catch {
                strong_self.errorHandler?(error)
            }
        }
    }

    open func cancel() {
        queue.sync {
            [weak self] in

            guard let strong_self = self else {
                return
            }

            if strong_self.resumed == false {
                return
            }
            do {
                try strong_self.udpChannel.cancel()
                strong_self.resumed = false
            }
            catch {
                strong_self.errorHandler?(error)
            }
        }
    }

    open func processDatagram(_ datagram: Datagram) {

        if resumed == false {
            return
        }

        postEvent(.packetReceived)

        do {
            guard let nalus = try rtpProcessor.process(datagram.data) else {
                return
            }

            postEvent(.naluProduced)

            for nalu in nalus {
                try processNalu(nalu)
            }
        }
        catch {
            postEvent(.errorInPipeline)
            errorHandler?(error)
        }
    }


    func processNalu(_ nalu: H264NALU) throws {
        do {
            guard let output = try h264Processor.process(nalu) else {
                return
            }

            switch output {
                case .formatDescription:
                    postEvent(.formatDescriptionProduced)
                case .sampleBuffer:
                    postEvent(.sampleBufferProduced)
            }

            postEvent(.h264FrameProduced)
            try handler?(output)
        }
        catch {
            switch error {
                case RTPError.skippedFrame:
                    postEvent(.h264FrameSkipped)
                case RTPError.fragmentationUnitError:
                    fallthrough
                default:
                    postEvent(.errorInPipeline)
            }
            throw error
        }
    }

    open func postEvent(_ event: RTPEvent) {
        eventHandler?(event)
    }
}

internal class RTPContext: RTPContextType {

    internal var eventHandler: ((RTPEvent) -> Void)?

    init() throws {
    }

    internal func postEvent(_ event: RTPEvent) {
        eventHandler?(event)
    }

}
