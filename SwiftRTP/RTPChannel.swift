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

public class RTPChannel {

    public private(set) var udpChannel:UDPChannel!
    public let rtpProcessor = RTPProcessor()
    public let h264Processor = H264Processor()
    public private(set) var resumed = false
    public private(set) var statistics = RTPStatistics()
    private var backgroundObserver: AnyObject?
    private var foregroundObserver: AnyObject?
    private let queue = dispatch_queue_create("SwiftRTP.RTPChannel", DISPATCH_QUEUE_SERIAL)

    public var handler:(H264Processor.Output throws -> Void)? {
        willSet {
            assert(resumed == false, "It is undefined to set properties while channel is resumed.")
        }
    }
    public var errorHandler:(ErrorType -> Void)? {
        willSet {
            assert(resumed == false, "It is undefined to set properties while channel is resumed.")
        }
    }
    public var statisticsHandler:(RTPStatistics -> Void)? {
        willSet {
            assert(resumed == false, "It is undefined to set properties while channel is resumed.")
        }
    }
    public var statisticsFrequency:Double = 30.0 {
        willSet {
            assert(resumed == false, "It is undefined to set properties while channel is resumed.")
        }
    }

    public init(port:UInt16) throws {

#if os(iOS)
        backgroundObserver = NSNotificationCenter.defaultCenter().addObserverForName(UIApplicationDidEnterBackgroundNotification, object: nil, queue: nil) {
            [weak self] (notification) in
            try! self?.cancel()
        }
        foregroundObserver = NSNotificationCenter.defaultCenter().addObserverForName(UIApplicationWillEnterForegroundNotification, object: nil, queue: nil) {
            [weak self] (notification) in
            try! self?.resume()
        }
#endif

        udpChannel = try UDPChannel(port: port) {
            [weak self] (datagram) in

            guard let strong_self = self else {
                return
            }

            dispatch_async(strong_self.queue) {
                strong_self.udpReadHandler(datagram)
            }
        }
    }

    deinit {
        if let backgroundObserver = backgroundObserver {
            NSNotificationCenter.defaultCenter().removeObserver(backgroundObserver)
        }
        if let foregroundObserver = foregroundObserver {
            NSNotificationCenter.defaultCenter().removeObserver(foregroundObserver)
        }
    }

    public func resume() throws {
        dispatch_sync(queue) {
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

    public func cancel() throws {

        dispatch_sync(queue) {
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

    private func udpReadHandler(datagram:Datagram) {

        if resumed == false {
            return
        }

        statistics.packetsReceived++

        let currentTime = CFAbsoluteTimeGetCurrent()

        defer {
            if let lastUpdate = statistics.lastUpdated {
                let delta = currentTime - lastUpdate
                if delta > (1.0 / statisticsFrequency) {
                    statisticsHandler?(statistics)
                }
            }
            statistics.lastUpdated = currentTime
        }

        do {
            guard let nalus = try rtpProcessor.process(datagram.data) else {
                return
            }

            statistics.nalusProduced += nalus.count

            for nalu in nalus {
                try processNalu(nalu)
            }
        }
        catch {
            switch error {
                case RTPError.fragmentationUnitError:
                    statistics.badSequenceErrors++
                    statistics.errorsProduced++
                default:
                    statistics.errorsProduced++
            }
            errorHandler?(error)
        }
    }


    func processNalu(nalu:H264NALU) throws {
        do {
            guard let output = try h264Processor.process(nalu) else {
                return
            }

            statistics.magic++

            switch output {
                case .formatDescription:
                    statistics.formatDescriptionsProduced++
                case .sampleBuffer:
                    statistics.sampleBuffersProduced++
            }

            statistics.h264FramesProduced++

            statistics.lastH264FrameProduced = CFAbsoluteTimeGetCurrent()
            try handler?(output)
        }
        catch {
            switch error {
                case RTPError.skippedFrame:
                    statistics.h264FramesSkipped++
                case RTPError.fragmentationUnitError:
                    fallthrough
                default:
                    statistics.errorsProduced++
            }
            throw error
        }
    }
}
