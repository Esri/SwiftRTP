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
import SwiftUtilities

public final class MovieWriter {
    public enum State {
        case initial
        case configured
        case recording
        case finished
    }

    public let movieURL: URL
    public let size: CGSize

    var writer: AVAssetWriter!
    var writerInput: AVAssetWriterInput!
    var writerAdaptor: AVAssetWriterInputPixelBufferAdaptor!

    public fileprivate(set) var state: State = .initial

    public init(movieURL: URL, size: CGSize) throws {


        self.movieURL = movieURL
        self.size = size

        writer = try AVAssetWriter(outputURL: movieURL, fileType: AVFileTypeQuickTimeMovie)
        writer.movieFragmentInterval = CMTimeMakeWithSeconds(1, 1)
        writer.shouldOptimizeForNetworkUse = true

        try MovieWriter.removeMovieFile(movieURL)

        //
        let videoSettings: [String: AnyObject] = [
            AVVideoCodecKey: AVVideoCodecH264 as AnyObject,
            AVVideoWidthKey: size.width as AnyObject,
            AVVideoHeightKey: size.height as AnyObject,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 10.1 * (size.width * size.height)
            ] as AnyObject
        ]
        writerInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = true

        writerAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: nil)

        if writer.canAdd(writerInput) == false {
            throw SwiftUtilities.Error.generic("Cannot add writer input")
            // return
        }
        writer.add(writerInput)

        writer.startWriting()

        state = .configured
    }

    public func resume() throws {
    }

    public func finishRecordingWithCompletionHandler(_ block: @escaping (_ success: Bool) -> Void) {
        if state != .recording {
            print("Movie is not recording", terminator: "")
            block(false)
            return
        }

        writer.finishWriting {
            let success = (self.writer.status == .completed)
            block(success)
        }

        state = .finished
    }

    public func handlePixelBuffer(_ pixelBuffer: CVPixelBuffer, presentationTime: CMTime) throws {
        if state == .configured {
            writer.startSession(atSourceTime: presentationTime)
            state = .recording
        }

        if state != .recording {
            throw SwiftUtilities.Error.generic("MovieWriter not recording.")
        }
        if writer.status != .writing {
            throw SwiftUtilities.Error.generic("MovieWriter.writer not writing.")
        }
        if writerInput.isReadyForMoreMediaData == false {
            throw SwiftUtilities.Error.generic("MovieWriter.writer not ready for more media data.")
        }

        writerAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
    }

    fileprivate static func removeMovieFile(_ movieURL: URL) throws {
        if FileManager().fileExists(atPath: movieURL.path) {
            try FileManager().removeItem(at: movieURL)
        }
    }
}
