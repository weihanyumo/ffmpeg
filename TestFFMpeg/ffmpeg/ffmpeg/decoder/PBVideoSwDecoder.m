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

static void ffmpeg_log_callback(void *ptr, int level, const char *fmt, va_list vl)
{
    if (level > av_log_get_level())
    {
        return;
    }
    char strLog[1024];
    
    const char *version = av_version_info();
    printf("PBVideoSwDecoder ffmpeg version:%s\n",version);
    
    vsprintf(strLog, fmt, vl);
    printf("PBVideoSwDecoder error :%s\n", strLog);
    
    AVClass *cls = ptr ? *(AVClass **)ptr : NULL;
    
    const char *module = cls ? cls->item_name(ptr) : "NULL";
    if (module) {
        printf("PBVideoSwDecoder error module:%s\n", module);
    }
}


@implementation PBVideoFrame
-(void)dealloc
{
    if (self.videoData) {
        free(self.videoData);
        self.videoData = NULL;
    }
}
@end


@implementation PBVideoSwDecoder
{
    AVCodec *avCodec;
    AVCodecContext *avCodecContext;
    AVFrame *avFrame;
    
    AVPacket packet;
    
    //test log
    float timeSumCost;
    float timeCount;
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
    
    av_log_set_level(AV_LOG_ERROR);
    av_log_set_callback(ffmpeg_log_callback);
    
    // find the decoder for H264
//    avCodec = avcodec_find_decoder(AV_CODEC_ID_H264);
    avCodec = avcodec_find_decoder(AV_CODEC_ID_H265);
    
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
//    avFrame = avcodec_alloc_frame();
    avFrame = av_frame_alloc();
    if (avFrame == NULL)
    {
        NSLog(@"Can not allocate frame");
        return NO;
    }
    
    avCodecContext->flags |= CODEC_FLAG_EMU_EDGE | CODEC_FLAG_LOW_DELAY;
    avCodecContext->debug |= FF_DEBUG_MMCO;
//    avCodecContext->pix_fmt = aPIX_FMT_YUV420P;
    avCodecContext->pix_fmt = AV_PIX_FMT_YUV420P;
    
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
//        avcodec_free_frame(&avFrame);
        av_frame_free(&avFrame);
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
    
//    int ret = avcodec_decode_video2(avCodecContext, avFrame, &gotLen, packet);
    NSTimeInterval time = [[NSDate date]timeIntervalSince1970];
    int ret = avcodec_decode_video2(avCodecContext, avFrame, &gotLen, &packet);
    NSTimeInterval cost = [[NSDate date]timeIntervalSince1970] - time;
    //    printf("decode cost time:%.3f\n", cost);
    if (timeCount++ < 50) {
        timeSumCost += cost;
    }
    else{
        printf("decode W:%d H:%d  avg cost :%.3f\n", avCodecContext->width, avCodecContext->height, timeSumCost / timeCount);
        timeCount = 0;
        timeSumCost = 0;
    }
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


void get_fixed_header(const unsigned char buff[7], adts_fixed_header *header) {
    unsigned long long adts = 0;
    const unsigned char *p = buff;
    adts |= *p ++; adts <<= 8;
    adts |= *p ++; adts <<= 8;
    adts |= *p ++; adts <<= 8;
    adts |= *p ++; adts <<= 8;
    adts |= *p ++; adts <<= 8;
    adts |= *p ++; adts <<= 8;
    adts |= *p ++;
    
    
    header->syncword                 = (adts >> 44);
    header->ID                       = (adts >> 43) & 0x01;
    header->layer                    = (adts >> 41) & 0x03;
    header->protection_absent        = (adts >> 40) & 0x01;
    header->profile                  = (adts >> 38) & 0x03;
    header->sampling_frequency_index = (adts >> 34) & 0x0e;
    header->private_bit              = (adts >> 33) & 0x01;
    header->channel_configuration    = (adts >> 30) & 0x07;
    header->original_copy            = (adts >> 29) & 0x01;
    header->home                     = (adts >> 28) & 0x01;
}

void get_variable_header(const unsigned char buff[7], adts_variable_header *header) {
    unsigned long long adts = 0;
    adts  = buff[0]; adts <<= 8;
    adts |= buff[1]; adts <<= 8;
    adts |= buff[2]; adts <<= 8;
    adts |= buff[3]; adts <<= 8;
    adts |= buff[4]; adts <<= 8;
    adts |= buff[5]; adts <<= 8;
    adts |= buff[6];
    
    header->copyright_identification_bit = (adts >> 27) & 0x01;
    header->copyright_identification_start = (adts >> 26) & 0x01;
    header->aac_frame_length = (adts >> 13) & ((int)pow(2, 14) - 1);
    header->adts_buffer_fullness = (adts >> 2) & ((int)pow(2, 11) - 1);
    header->number_of_raw_data_blocks_in_frame = adts & 0x03;
}

