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
    var movieWriter:MovieWriter? = nil
    var statistics:[RTPEvent:Int] = [:]

    @IBOutlet var videoView: VideoView!
    @IBOutlet var statisticsView: UITextView!

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

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
                            print("ERROR: \(error)")
                    }
                default:
                    print("ERROR: \(error)")
            }
        }
        rtpChannel.eventHandler = {
            (event) in
            dispatch_async(dispatch_get_main_queue()) {

                if self.statistics[event] == nil {
                    self.statistics[event] = 0
                }
                else {
                    self.statistics[event] = self.statistics[event]! + 1
                }

                self.statisticsView.text = self.statistics.map() { return "\($0): \($1)" }.joinWithSeparator(" \n")
            }
        }

        try rtpChannel.resume()
    }
}
