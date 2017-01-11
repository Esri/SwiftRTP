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

    var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer!

    override var bounds: CGRect {
        didSet {
            sampleBufferDisplayLayer?.frame = self.bounds
        }
    }

    override var frame: CGRect {
        didSet {
            sampleBufferDisplayLayer?.frame = self.bounds
        }
    }

    required init?(coder aDecoder: NSCoder) {

        super.init(coder: aDecoder)

        rebuildSampleBufferDisplayLayer()
    }

    func rebuildSampleBufferDisplayLayer() {

        if sampleBufferDisplayLayer != nil {
            sampleBufferDisplayLayer.removeFromSuperlayer()
        }

        sampleBufferDisplayLayer = AVSampleBufferDisplayLayer()
        sampleBufferDisplayLayer.frame = self.bounds
        layer.addSublayer(sampleBufferDisplayLayer)
    }
}

// MARK: -

extension VideoView {
    func process(input: H264Processor.Output?) {
        guard let input = input else {
            return
        }

        switch input {
            case .formatDescription:
                // Nothing to do here?
                break
            case .sampleBuffer(let sampleBuffer):
                if sampleBufferDisplayLayer.error != nil {
                    rebuildSampleBufferDisplayLayer()
                }
                sampleBufferDisplayLayer.enqueue(sampleBuffer)
        }
    }
}
