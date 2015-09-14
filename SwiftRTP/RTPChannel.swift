//
//  RTPChannel.swift
//  RTP Test
//
//  Created by Jonathan Wight on 6/30/15.
//  Copyright © 2015 3D Robotics Inc. All rights reserved.
//

import CoreMedia

import SwiftUtilities
import SwiftIO

public class RTPChannel {

    public struct Statistics {
        public var lastUpdated: CFAbsoluteTime? = nil
        public var packetsReceived: Int = 0
        public var nalusProduced: Int = 0
        public var h264FramesProduced: Int = 0
        public var formatDescriptionsProduced: Int = 0
        public var sampleBuffersProduced: Int = 0
        public var lastH264FrameProduced: CFAbsoluteTime? = nil
        public var errorsProduced: Int = 0
        public var h264FramesSkipped: Int = 0
    }

    public private(set) var udpChannel:UDPChannel!
    public let rtpProcessor = RTPProcessor()
    public let h264Processor = H264Processor()
    public private(set) var resumed = false
    public private(set) var statistics = Statistics()

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
    public var statisticsHandler:(Statistics -> Void)? {
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
        udpChannel = try UDPChannel(port: port) {
            [weak self] (datagram) in
            do {
                try self?.udpReadHandler(datagram)
            }
            catch RTPError.skippedFrame {
            }
            catch let error {
                debugLog?("Error caught: \(error)")
            }
        }
    }

    public func resume() throws {
        if resumed == true {
            return
        }
        try udpChannel.resume()
        resumed = true
    }

    public func cancel() throws {
        if resumed == false {
            return
        }
        try udpChannel.cancel()
        resumed = false
    }

    public func udpReadHandler(datagram:Datagram) throws {
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

        guard let nalus = try rtpProcessor.process(datagram.data) else {
            return
        }

        statistics.nalusProduced += nalus.count

        for nalu in nalus {
            do {
                guard let output = try h264Processor.process(nalu) else {
                    continue
                }

                switch output {
                    case .formatDescription:
                        statistics.formatDescriptionsProduced++
                    case .sampleBuffer:
                        statistics.sampleBuffersProduced++
                }

                statistics.h264FramesProduced++
                statistics.lastH264FrameProduced = currentTime
                try handler?(output)
            }

            catch let error {
                switch error {
                    case RTPError.skippedFrame:
                        statistics.h264FramesSkipped++
                    default:
                        statistics.errorsProduced++
                }
                self.errorHandler?(error)
            }
        }
    }
}
