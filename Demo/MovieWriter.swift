//
//  MovieWriter.swift
//  SwiftRTP
//
//  Created by Jonathan Wight on 8/24/15.
//  Copyright (c) 2015 schwa. All rights reserved.
//

import AVFoundation
import Foundation
import SwiftRTP

public final class MovieWriter
{
    public enum State {
        case Initial
        case Configured
        case Recording
        case Finished
    }

    public let movieURL: NSURL
    public let size: CGSize

    let writer: AVAssetWriter!
    let writerInput: AVAssetWriterInput!
    let writerAdaptor: AVAssetWriterInputPixelBufferAdaptor!

    public private(set) var state: State = .Initial

    public init(movieURL: NSURL, size: CGSize, inout error:ErrorType?) {

        MovieWriter.removeMovieFile(movieURL)

        self.movieURL = movieURL
        self.size = size

        var nsError: NSError? = nil
        writer = AVAssetWriter(URL: movieURL, fileType: AVFileTypeQuickTimeMovie, error: &nsError)
        if writer == nil {
            error = RTPError.generic("Failed to create asset writer: \(error)")
            // return
        }
        writer.movieFragmentInterval = CMTimeMakeWithSeconds(1, 1)
        writer.shouldOptimizeForNetworkUse = true

        //
        let videoSettings: [NSObject: AnyObject] = [
            AVVideoCodecKey: AVVideoCodecH264,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 10.1 * (size.width * size.height)
            ]
        ]
        writerInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = true

        writerAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: nil)

        if writer.canAddInput(writerInput) == false {
            error = RTPError.generic("Cannot add writer input")
            // return
        }
        writer.addInput(writerInput)

        writer.startWriting()

        state = .Configured
    }

    public func resume(inout error:ErrorType?) -> Bool {
        return true
    }

    public func finishRecordingWithCompletionHandler(block: (success: Bool) -> Void) {
        if state != .Recording {
            print("Movie is not recording")
            block(success: false)
            return
        }

        writer.finishWritingWithCompletionHandler {
            let success = (self.writer.status == .Completed)
            block(success: success)
        }

        state = .Finished
    }

    public func handlePixelBuffer(pixelBuffer:CVPixelBuffer, presentationTime:CMTime, inout error:ErrorType?) -> Bool {
        if state == .Configured {
            writer.startSessionAtSourceTime(presentationTime)
            state = .Recording
        }

        if state != .Recording {
            error = RTPError.generic("MovieWriter not recording.")
            return false
        }
        if writer.status != .Writing {
            error = RTPError.generic("MovieWriter.writer not writing.")
            return false
        }
        if writerInput.readyForMoreMediaData == false {
            error = RTPError.generic("MovieWriter.writer not ready for more media data.")
            return false
        }

        writerAdaptor.appendPixelBuffer(pixelBuffer, withPresentationTime: presentationTime)

        return true
    }

    private static func removeMovieFile(movieURL:NSURL) -> Bool {
        if NSFileManager().fileExistsAtPath(movieURL.path!) {
            if NSFileManager().removeItemAtURL(movieURL, error: nil) == false {
                return false
            }
        }
        return true
    }
}
