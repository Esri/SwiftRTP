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
        // swiftlint:disable:next force_cast
        return layer as! AVSampleBufferDisplayLayer
        // swiftlint:enable:next force_cast
    }
}

// MARK: -

extension VideoView {

    func process(_ input: H264Processor.Output?) {
        guard let input = input else {
            return
        }
        switch input {
            case .formatDescription:
                // Nothing to do here?
                break
            case .sampleBuffer(let sampleBuffer):
                sampleBufferDisplayLayer.enqueue(sampleBuffer)
        }
    }
}
