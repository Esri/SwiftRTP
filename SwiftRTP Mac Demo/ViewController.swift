//
//  ViewController.swift
//  RTP Test
//
//  Created by Jonathan Wight on 6/23/15.
//  Copyright © 2015 3D Robotics Inc. All rights reserved.
//

// swiftlint:disable force_try

import Cocoa
import AVFoundation
import CoreMedia

import SwiftRTP
import SwiftIO

class ViewController: NSViewController {

    var rtpChannel: RTPChannel!
    var tcpChannel: TCPChannel!

    var decompressionSession: DecompressionSession? = nil
    var movieWriter: MovieWriter? = nil

    @IBOutlet var videoView: VideoView!
    @IBOutlet var statisticsView: NSTextView!

    var statistics: [RTPEvent: Int] = [:]


    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        ProcessInfo.processInfo.beginActivity(options: .latencyCritical, reason: "Because")

//        movieWriter = try! MovieWriter(movieURL: NSURL(fileURLWithPath: "/Users/schwa/Desktop/Test.h264"), size: CGSize(width: 1280, height: 7820))
//        try! movieWriter?.resume()

        decompressionSession = DecompressionSession()
//        decompressionSession?.imageBufferDecoded = {
//            (imageBuffer: CVImageBuffer, presentationTimeStamp: CMTime, presentationDuration: CMTime) -> Void in
//            if let movieWriter = self.movieWriter {
//                do {
//                    try movieWriter.handlePixelBuffer(imageBuffer, presentationTime: presentationTimeStamp)
//                }
//                catch {
//                    print(error)
//                }
//            }
//        }

        try! startUDP()
    }

    func startUDP() throws {

        let address = try! Address(address: "10.1.1.1", port: 5502)

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

                strong_self.videoView.process(output)
                if strong_self.decompressionSession != nil {
                    try! strong_self.decompressionSession?.process(output)
                }
            }
        }
        rtpChannel.errorHandler = {
            (error) in

            print("ERROR: \(error)")

            switch error {
                case let error as RTPError:
                    switch error {
                        case .fragmentationUnitError:
                            return
                        default:
                            print("Error handler caught: \(error)")
                    }
                default:
                    print("Error handler caught: \(error)")
            }
        }
        rtpChannel.eventHandler = {
            (event) in

            DispatchQueue.main.async {

                if self.statistics[event] == nil {
                    self.statistics[event] = 0
                }
                else {
                    self.statistics[event] = self.statistics[event]! + 1
                }

                self.statisticsView.string = self.statistics.map() { return "\($0): \($1)" }.joined(separator: " \n")
            }
        }

        rtpChannel.resume()
    }

    @IBAction func logStatistics(_ sender: AnyObject?) {
//        print(rtpChannel.udpChannel.memoryPool.statistics)
    }
}
