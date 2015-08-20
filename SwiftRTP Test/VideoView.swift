//
//  VideoView.swift
//  RTP Test
//
//  Created by Jonathan Wight on 6/25/15.
//  Copyright © 2015 3D Robotics Inc. All rights reserved.
//

import Cocoa
import AVFoundation

import SwiftRTP

class VideoView: NSView {

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override func makeBackingLayer() -> CALayer {
        return AVSampleBufferDisplayLayer()
    }

    var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer {
        return layer as! AVSampleBufferDisplayLayer
    }
}

// MARK: -

extension VideoView {

    func process(input:H264Processor.Output?) {
        if let input = input {
        switch input {
                case .formatDescription:
                    // Nothing to do here?
                    break
                case .sampleBuffer(let sampleBuffer):
                    sampleBufferDisplayLayer.enqueueSampleBuffer(sampleBuffer)
            }
        }
    }
}
