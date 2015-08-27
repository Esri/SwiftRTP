//
//  RTPChannel.swift
//  RTP Test
//
//  Created by Jonathan Wight on 6/30/15.
//  Copyright © 2015 3D Robotics Inc. All rights reserved.
//

import CoreMedia

public class RTPChannel {

    public struct Statistics {
        public var lastUpdated: CFAbsoluteTime? = nil
        public var packetsReceived: Int = 0
        public var nalusProduced: Int = 0
        public var h264FramesProduced: Int = 0
        public var lastH264FrameProduced: CFAbsoluteTime? = nil
        public var errorsProduced: Int = 0
    }

    public private(set) var udpChannel:UDPChannel!
    public let rtpProcessor = RTPProcessor()
    public let h264Processor = H264Processor()
    public private(set) var resumed = false
    public private(set) var statistics = Statistics()

    public var handler:(H264Processor.Output -> Void)? {
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
    public var statisticsFrequency:Double = 10.0 {
        willSet {
            assert(resumed == false, "It is undefined to set properties while channel is resumed.")
        }
    }

    public init(port:UInt16) {
        udpChannel = UDPChannel(port: port) {
            [weak self] (datagram) in
            self?.udpReadHandler(datagram)
        }
    }

    public func resume() {
        if resumed == true {
            return
        }
        var error:ErrorType?
        udpChannel.resume(&error)
        resumed = true
    }

    public func cancel() {
        if resumed == false {
            return
        }
        udpChannel.cancel()
        resumed = false
    }

    public func udpReadHandler(datagram:Datagram) {
        statistics.packetsReceived++

        var statisticsUpdated = false
        let currentTime = CFAbsoluteTimeGetCurrent()

        var error:ErrorType? = nil
        if let nalus = rtpProcessor.process(datagram.data, error:&error) {
            statistics.nalusProduced += nalus.count

            for nalu in nalus {
                if let output = h264Processor.process(nalu, error:&error) {
                	statistics.h264FramesProduced++
                    statistics.lastH264FrameProduced = currentTime
                	handler?(output)
                	statisticsUpdated = true
            	}
                else if let error = error {
                    errorHandler?(error)
                }
            }
        }

        if let error = error {
            self.errorHandler?(error)
            statistics.errorsProduced++
            statisticsUpdated = true
        }

        if statisticsUpdated == true {
            if let lastUpdate = statistics.lastUpdated {
                if currentTime - lastUpdate < 1.0 / statisticsFrequency {
                    return
                }
            }
            statistics.lastUpdated = currentTime
            statisticsHandler?(statistics)
        }
    }
}
