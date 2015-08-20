//
//  RTPChannel.swift
//  RTP Test
//
//  Created by Jonathan Wight on 6/30/15.
//  Copyright © 2015 schwa. All rights reserved.
//

import CoreMedia

public class RTPChannel {

    public struct Statistics {
        public var packetsReceived: Int = 0
        public var nalusProduced: Int = 0
        public var h264FramesProduced: Int = 0
        public var errorsProduced: Int = 0
    }

    public internal(set) var udpChannel:UDPChannel!
    public let rtpProcessor = RTPProcessor()
    public let h264Processor = H264Processor()

    public var handler:(H264Processor.Output -> Void)?
    public var errorHandler:(ErrorType -> Void)?
    public var statisticsHandler:(Statistics -> Void)?

    public internal(set) var statistics = Statistics()

    public init(port:UInt16) {

        udpChannel = UDPChannel(port: port) {
            [weak self] (datagram) in
            self?.udpReadHandler(datagram)
        }
    }

    public func resume() {
        var error:ErrorType?
        udpChannel.resume(&error)
    }

    public func cancel() {
        udpChannel.cancel()
    }

    public func udpReadHandler(datagram:Datagram) {
        statistics.packetsReceived++

        let data = datagram.data

        var error:ErrorType? = nil
        if let nalus = rtpProcessor.process(data, error:&error) {
            statistics.nalusProduced += nalus.count

            for nalu in nalus {
                if let output = h264Processor.process(nalu, error:&error) {
                	statistics.h264FramesProduced++
                	handler?(output)
                	statisticsHandler?(statistics)
            	}
                else if let error = error {
                    errorHandler?(error)
                }
            }
        }

        if let error = error {
            self.errorHandler?(error)

            statistics.errorsProduced++
            statisticsHandler?(statistics)
        }
    }
}
