//
//  ViewController.swift
//  RTP Test
//
//  Created by Jonathan Wight on 6/23/15.
//  Copyright © 2015 3D Robotics Inc. All rights reserved.
//

import Cocoa
import AVFoundation
import CoreMedia

import SwiftRTP

class ViewController: NSViewController {

    var rtpChannel:RTPChannel!
    var tcpChannel:TCPChannel!

    let decompressionSession = DecompressionSession()
    var movieWriter:MovieWriter? = nil

    @IBOutlet var videoView: VideoView!
    dynamic var packetsReceived: Int = 0
    dynamic var nalusProduced: Int = 0
    dynamic var h264FramesProduced: Int = 0
    dynamic var h264FramesSkipped: Int = 0
    dynamic var h264ProductionErrorsProduced: Int = 0
    dynamic var lastH264FrameProduced: NSDate? = nil
    dynamic var formatDescriptionsProduced: Int = 0
    dynamic var sampleBuffersProduced: Int = 0


    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        NSProcessInfo.processInfo().beginActivityWithOptions(.LatencyCritical, reason: "Because")

//        movieWriter = MovieWriter(movieURL:NSURL(fileURLWithPath: "/Users/schwa/Desktop/Test.h264")!, size:CGSize(width: 1280, height: 7820), error:&error)
//        movieWriter?.resume(&error)

        decompressionSession.imageBufferDecoded = {
            (imageBuffer:CVImageBuffer, presentationTimeStamp:CMTime, presentationDuration:CMTime) -> Void in
            try! self.movieWriter?.handlePixelBuffer(imageBuffer, presentationTime: presentationTimeStamp)
        }

        try! startUDP()
    }

    func startUDP() throws {

        tcpChannel = TCPChannel(hostname:"10.1.1.1", port:5502)
        try tcpChannel.resume()


        rtpChannel = try RTPChannel(port:5600)
        rtpChannel.handler = {
            (output) -> Void in
            dispatch_async(dispatch_get_main_queue()) {
                [weak self] in

                guard let strong_self = self else {
                    return
                }

                strong_self.videoView.process(output)
                if strong_self.movieWriter != nil {
                    try! strong_self.decompressionSession.process(output)
                }
            }
        }
        rtpChannel.errorHandler = {
            (error) in

            switch error {
                case let error as RTPError:
                    switch error {
                        case .skippedFrame:
                            return
                        default:
                            print("Error handler caught: \(error)")
                    }
                default:
                    print("Error handler caught: \(error)")
            }
        }
        rtpChannel.statisticsHandler = {
            (statistics) in

            dispatch_async(dispatch_get_main_queue(), {
                self.packetsReceived = statistics.packetsReceived
                self.nalusProduced = statistics.nalusProduced
                self.h264FramesProduced = statistics.h264FramesProduced
                self.h264ProductionErrorsProduced = statistics.errorsProduced
                self.lastH264FrameProduced = NSDate(timeIntervalSinceReferenceDate: statistics.lastH264FrameProduced ?? 0)
                self.h264FramesSkipped = statistics.h264FramesSkipped
                self.sampleBuffersProduced = statistics.sampleBuffersProduced
                self.formatDescriptionsProduced = statistics.formatDescriptionsProduced
            })
        }

        try rtpChannel.resume()
    }
}
