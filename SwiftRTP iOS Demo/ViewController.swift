//
//  ViewController.swift
//  SwiftRTP iOS Test
//
//  Created by Jonathan Wight on 8/20/15.
//  Copyright (c) 2015 schwa. All rights reserved.
//

import UIKit

import SwiftRTP

class ViewController: UIViewController {

    var rtpChannel:RTPChannel!
    var tcpChannel:TCPChannel!

    let decompressionSession = DecompressionSession()

    @IBOutlet var videoView: VideoView!
    dynamic var packetsReceived: Int = 0
    dynamic var nalusProduced: Int = 0
    dynamic var h264FramesProduced: Int = 0
    dynamic var h264ProductionErrorsProduced: Int = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        startUDP()
    }

    func startUDP() {
//        let SPS:[UInt8] = [ 0x68, 0xCE, 0x30, 0xA6, 0x80 ]
//        let PPS:[UInt8] = [ 0x67, 0x42, 0x40, 0x1F, 0xA6, 0x80, 0x50, 0x05, 0xB9 ]
//
//        let SPSData = DispatchData <UInt8> (value:SPS)
//        let PPSData = DispatchData <UInt8> (value:PPS)
//
//        let description = makeFormatDescription(DispatchData <Void> (data:SPSData.data), DispatchData <Void> (data:PPSData.data), error: &error)
//        print(description)

//        tcpChannel = TCPChannel(hostname:"10.1.1.1", port:5502)
//        tcpChannel.resume(&error)

        rtpChannel = RTPChannel(port:5600)
        rtpChannel.handler = {
            (output) -> Void in
            dispatch_async(dispatch_get_main_queue()) {
                [weak self] in

                if let strong_self = self {
                    strong_self.videoView.process(output)

                    var error: ErrorType?
                    strong_self.decompressionSession.process(output, error:&error)
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
                            print("ERROR: \(error)")
                    }
                default:
                    print(")ERROR: \(error)")
            }
        }
        rtpChannel.statisticsHandler = {
            (statistics) in

            dispatch_async(dispatch_get_main_queue(), {
                self.packetsReceived = statistics.packetsReceived
                self.nalusProduced = statistics.nalusProduced
                self.h264FramesProduced = statistics.h264FramesProduced
                self.h264ProductionErrorsProduced = statistics.errorsProduced
            })
        }

        rtpChannel.resume()
    }
}


