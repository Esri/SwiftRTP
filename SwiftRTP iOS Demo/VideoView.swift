//
//  VideoView.swift
//  SwiftRTP
//
//  Created by Jonathan Wight on 8/20/15.
//  Copyright (c) 2015 schwa. All rights reserved.
//

import UIKit
import AVFoundation

import SwiftRTP

class VideoView: UIView {

    override class func layerClass() -> AnyClass {
        return AVSampleBufferDisplayLayer.self
    }

    var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer {
        return layer as! AVSampleBufferDisplayLayer
    }
}

// MARK: -

extension VideoView {
    func process(input:H264Processor.Output?) {
        guard let input = input else {
            return
        }

        switch input {
            case .formatDescription:
                // Nothing to do here?
                break
            case .sampleBuffer(let sampleBuffer):
                sampleBufferDisplayLayer.enqueueSampleBuffer(sampleBuffer)
        }
    }
}
