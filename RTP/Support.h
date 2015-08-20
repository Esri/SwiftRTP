//
//  Support.h
//  RTP Test
//
//  Created by Jonathan Wight on 8/13/15.
//  Copyright © 2015 schwa. All rights reserved.
//

#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <VideoToolbox/VideoToolbox.h>

#ifndef Support_h
#define Support_h

extern void CMSampleBufferSetDisplayImmediately(CMSampleBufferRef sampleBuffer);

typedef void (^VTDecompressionOutputCallbackBlock)(void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef imageBuffer, CMTime presentationTimeStamp, CMTime presentationDuration);

OSStatus VTDecompressionSessionCreateWithBlock(CFAllocatorRef allocator, CMVideoFormatDescriptionRef videoFormatDescription, CFDictionaryRef videoDecoderSpecification, CFDictionaryRef destinationImageBufferAttributes, const VTDecompressionOutputCallbackBlock block, VTDecompressionSessionRef *decompressionSessionOut);


#endif /* Support_h */
