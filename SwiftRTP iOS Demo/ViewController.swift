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

        print(try! Address.addressesForInterfaces()["en0"]!)


//        movieWriter = MovieWriter(movieURL: NSURL(fileURLWithPath: "/Users/schwa/Desktop/Test.h264")!, size: CGSize(width: 1280, height: 7820), error: &error)
//        movieWriter?.resume(&error)

        decompressionSession.imageBufferDecoded = {
            (imageBuffer: CVImageBuffer, presentationTimeStamp: CMTime, presentationDuration: CMTime) -> Void in
            try! self.movieWriter?.handlePixelBuffer(imageBuffer, presentationTime: presentationTimeStamp)
        }

        try! startUDP()
    }

    func startUDP() throws {

        let address = try Address(address: "10.1.1.1", port: 5502)

        tcpChannel = TCPChannel(address: address)
        tcpChannel.connect() {
            result in
        }


        rtpChannel = try RTPChannel(port: 5600)
        rtpChannel.handler = {
            (output) -> Void in
            DispatchQueue.main.async {
                [weak self] in

                guard let strong_self = self else {
                    return
                }

                strong_self.videoView.process(input: output)
                if strong_self.movieWriter != nil {
                    try! strong_self.decompressionSession.process(output)
                }
            }
        }
        rtpChannel.errorHandler = {
            (error) in

            DispatchQueue.main.async {
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
                DispatchQueue.main.async {
                    if self.statistics[event] == nil {
                        self.statistics[event] = 1
                    }
                    else {
                        self.statistics[event] = self.statistics[event]! + 1
                    }

                    Throttler.with(name: "statistics", minimumInterval: 1/10) {
                        var string = NSMutableAttributedString()
                        for (event, value) in self.statistics {
                            let color = self.heartbeatView.colorForEvent(event: String(describing: event))
                            string += NSAttributedString(string: "•", attributes: [NSForegroundColorAttributeName : color])
                            string += NSAttributedString(string: "\(event): \(value)\n", attributes: [NSForegroundColorAttributeName : UIColor.white])
                        }
                        self.statisticsView.attributedText = string
                    }
                    self.heartbeatView.handleEvent(event: String(describing: event))
                }
            }
        }
        rtpChannel.resume()
    }
}

extension NSMutableString {
}

func += ( lhs: inout NSMutableAttributedString, rhs: NSAttributedString) -> NSMutableAttributedString {
    lhs.append(rhs)
    return lhs
}

class Throttler {

    static var throttles: [String: CFAbsoluteTime] = [:]

    static func with(name: String, minimumInterval: TimeInterval, action: () -> Void) {
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
