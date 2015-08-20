//
//  Support.m
//  RTP Test
//
//  Created by Jonathan Wight on 8/13/15.
//  Copyright © 2015 schwa. All rights reserved.
//

#import "Support.h"

#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <VideoToolbox/VideoToolbox.h>

static void RTP_VTDecompressionOutputCallback(void *decompressionOutputRefCon, void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef imageBuffer, CMTime presentationTimeStamp, CMTime presentationDuration);

void CMSampleBufferSetDisplayImmediately(CMSampleBufferRef sampleBuffer) {
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, YES);
    CFMutableDictionaryRef dict = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
    CFDictionarySetValue(dict, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);
}

// MARK: -

OSStatus VTDecompressionSessionCreateWithBlock(CFAllocatorRef allocator, CMVideoFormatDescriptionRef videoFormatDescription, CFDictionaryRef videoDecoderSpecification, CFDictionaryRef destinationImageBufferAttributes, const VTDecompressionOutputCallbackBlock block, VTDecompressionSessionRef *decompressionSessionOut) {
    VTDecompressionOutputCallbackRecord callback = {
        .decompressionOutputCallback = RTP_VTDecompressionOutputCallback,
        .decompressionOutputRefCon = Block_copy((__bridge void *)block), // TODO: Leak???
    };
    return VTDecompressionSessionCreate(allocator, videoFormatDescription, videoDecoderSpecification, destinationImageBufferAttributes, &callback, decompressionSessionOut);
}

static void RTP_VTDecompressionOutputCallback(void *decompressionOutputRefCon, void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef imageBuffer, CMTime presentationTimeStamp, CMTime presentationDuration) {
    VTDecompressionOutputCallbackBlock block = (__bridge VTDecompressionOutputCallbackBlock)decompressionOutputRefCon;
    block(sourceFrameRefCon, status, infoFlags, imageBuffer, presentationTimeStamp, presentationDuration);
}
