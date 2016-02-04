//
//  ViewController.swift
//  SwiftRTP iOS Test
//
//  Created by Jonathan Wight on 8/20/15.
//  Copyright (c) 2015 schwa. All rights reserved.
//

// swiftlint:disable force_try

import UIKit

import SwiftRTP
import SwiftIO

class ViewController: UIViewController {

    var rtpChannel: RTPChannel!
    var tcpChannel: TCPChannel!
    let decompressionSession = DecompressionSession()
    var movieWriter: MovieWriter? = nil
    var statistics: [RTPEvent: Int] = [:]

    @IBOutlet var videoView: VideoView!
    @IBOutlet var statisticsView: UITextView!
    @IBOutlet var heartbeatView: HeartbeatView!

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        statisticsView.text = ""

        print(try! Address.addressesForInterfaces()["en0"])


//        movieWriter = MovieWriter(movieURL: NSURL(fileURLWithPath: "/Users/schwa/Desktop/Test.h264")!, size: CGSize(width: 1280, height: 7820), error: &error)
//        movieWriter?.resume(&error)

        decompressionSession.imageBufferDecoded = {
            (imageBuffer: CVImageBuffer, presentationTimeStamp: CMTime, presentationDuration: CMTime) -> Void in
            try! self.movieWriter?.handlePixelBuffer(imageBuffer, presentationTime: presentationTimeStamp)
        }

        try! startUDP()
    }

    func startUDP() throws {

        tcpChannel = TCPChannel(hostname: "10.1.1.1", port: 5502)
        try tcpChannel.resume()


        rtpChannel = try RTPChannel(port: 5600)
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

            dispatch_async(dispatch_get_main_queue()) {
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
        }
        rtpChannel.eventHandler = {
            (event) in

            if true {
                dispatch_async(dispatch_get_main_queue()) {
                    if self.statistics[event] == nil {
                        self.statistics[event] = 1
                    }
                    else {
                        self.statistics[event] = self.statistics[event]! + 1
                    }

                    Throttler.with("statistics", minimumInterval: 1/10) {
                        var string = NSMutableAttributedString()
                        for (event, value) in self.statistics {
                            let color = self.heartbeatView.colorForEvent(String(event))
                            string += NSAttributedString(string: "•", attributes: [NSForegroundColorAttributeName : color])
                            string += NSAttributedString(string: "\(event): \(value)\n", attributes: [NSForegroundColorAttributeName : UIColor.whiteColor()])
                        }
                        self.statisticsView.attributedText = string
                    }
                    self.heartbeatView.handleEvent(String(event))
                }
            }
        }
        try rtpChannel.resume()
    }
}

extension NSMutableString {
}

func += (inout lhs: NSMutableAttributedString, rhs: NSAttributedString) -> NSMutableAttributedString {
    lhs.appendAttributedString(rhs)
    return lhs
}

class Throttler {

    static var throttles: [String: CFAbsoluteTime] = [:]

    static func with(name: String, minimumInterval: NSTimeInterval, action: () -> Void) {
        let now = CFAbsoluteTimeGetCurrent()
        if let last = throttles[name] {
            let delta = now - last
            if delta > minimumInterval {
                action()
                throttles[name] = now
            }
        }
        else {
            action()
            throttles[name] = now
        }
    }

}
