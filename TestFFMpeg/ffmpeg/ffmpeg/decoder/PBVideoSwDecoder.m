//
//  PBVideoSwDecoder.m
//  VoIPBase
//
//  Created by 李油 on 8/12/15.
//  Copyright (c) 2015 huanghua. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PBVideoSwDecoder.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIImage.h>
#import <CoreGraphics/CGBase.h>
#import <QuartzCore/QuartzCore.h>
#import <Accelerate/Accelerate.h>

//#import "yuv2rgb.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>

#include "libavcodec/avcodec.h"
#include "libavutil/opt.h"
#include "libavutil/mathematics.h"
#include "libavformat/avformat.h"
#include "libavutil/imgutils.h"
#include "libavutil/samplefmt.h"
#include "libavutil/timestamp.h"

#include "libswscale/swscale.h"
#include "libswresample/swresample.h"

#define MAX_YUV_BUFFER_LENGTH 1920*1080*2

@implementation PBVideoFrame

@end


@implementation PBVideoSwDecoder
{
    AVCodec *avCodec;
    AVCodecContext *avCodecContext;
    AVFrame *avFrame;
    
    AVPacket packet;
    
    unsigned char *yuvBuffer;
    BOOL isFFMpegInit;
}

-(id)initWithDelegate:(id)aDelegate
{
//    if(self = [super initWithDelegate:aDelegate])
    if(self = [super init])
    {
        avCodec = NULL;
        avCodecContext = NULL;
        avFrame = NULL;
        
        isFFMpegInit = NO;
        
        [self initFFMpeg];
    }
    return  self;
}

-(BOOL)initFFMpeg
{
    avcodec_register_all();
    
    // find the decoder for H264
    avCodec = avcodec_find_decoder(AV_CODEC_ID_H264);
    
    if (avCodec == NULL)
    {
        NSLog(@"Can not find H264 decoder.");
        return NO;
    }
    
    avCodecContext = avcodec_alloc_context3(avCodec);
    if(avCodecContext == NULL)
    {
        return NO;
    }
    
    if (avcodec_open2(avCodecContext, avCodec, NULL) < 0)
    {
        NSLog(@"Can not open codec.");
        return NO;
    }
    
    // allocate frame
    avFrame = avcodec_alloc_frame();
    if (avFrame == NULL)
    {
        NSLog(@"Can not allocate frame");
        return NO;
    }
    
    avCodecContext->flags |= CODEC_FLAG_EMU_EDGE | CODEC_FLAG_LOW_DELAY;
    avCodecContext->debug |= FF_DEBUG_MMCO;
    avCodecContext->pix_fmt = PIX_FMT_YUV420P;
    
    isFFMpegInit = YES;
    
    return YES;
}

-(BOOL)reinitFFMpeg
{
    [self deInitFFMpeg];
    return [self initFFMpeg];
}

-(void)deInitFFMpeg
{
    isFFMpegInit = NO;
    
    if(avFrame != NULL)
    {
        avcodec_free_frame(&avFrame);
        avFrame = NULL;
    }
    
    if(avCodecContext != NULL)
    {
        avcodec_close(avCodecContext);
        av_free(avCodecContext);
        avCodecContext = NULL;
    }
}

-(int)frameWidth
{
    return avCodecContext ? avCodecContext->width : 0;
}

-(int)frameHeight
{
    return avCodecContext ? avCodecContext->height : 0;
}

-(PBVideoFrame *)decodePackeg:(AVPacket *)packet
{
    if(isFFMpegInit == NO)
    {
        if([self reinitFFMpeg] == NO)
            return NULL;
    }
    
    int gotLen = 0;
    int ret = avcodec_decode_video2(avCodecContext, avFrame, &gotLen, packet);
    
    if (gotLen == 0 || ret <= 0)
    {
        NSLog(@"Decode Video Frame ==> errCode:%d,seqNumber:%d,isIFrame:%d",ret,6, 0);
    }
    
    if (gotLen == 0 || ret <= 0)
    {
        NSLog(@"Decode Video Frame ==> errCode:%d,seqNumber:%d,isIFrame:%d",ret,2,3);
        return NULL;
    }
    
    NSTimeInterval nowTime = [[NSDate date] timeIntervalSince1970];
    if(!yuvBuffer)
    {
        yuvBuffer = (unsigned char *)malloc(MAX_YUV_BUFFER_LENGTH);
    }
    unsigned char *bufferOffset = yuvBuffer;
    
    int dataLength = 0;
    
    int width = MIN(avFrame->linesize[0], avCodecContext->width);
    int size = width * avCodecContext->height;
    memcpy(yuvBuffer, avFrame->data[0], size);
    bufferOffset += size;
    dataLength += size;
    
    width = MIN(avFrame->linesize[1], avCodecContext->width/2);
    size = width * (avCodecContext->height / 2);
    memcpy(bufferOffset, avFrame->data[1],size);
    bufferOffset += size;
    dataLength += size;
    
    width = MIN(avFrame->linesize[2], avCodecContext->width/2);
    size = width *(avCodecContext->height / 2);
    memcpy(bufferOffset, avFrame->data[2],size);
    bufferOffset += size;
    dataLength += size;
    
    PBVideoFrame *pvFrame = [[PBVideoFrame alloc]init];
    
    pvFrame.videoData = (unsigned char *)malloc(dataLength);//yuvBuffer;
    memcpy(pvFrame.videoData, yuvBuffer, dataLength);
    pvFrame.dataLength = dataLength;
    pvFrame.width = avCodecContext->width;
    pvFrame.height = avCodecContext->height;
    
    return pvFrame;
}

- (void)dealloc
{
    [self deInitFFMpeg];
    
    avCodec = NULL;
    avCodecContext = NULL;
    avFrame = NULL;
}

@end
