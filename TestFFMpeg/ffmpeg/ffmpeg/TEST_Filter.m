//
//  TEST_Filter.c
//  ffmpeg
//
//  Created by duhaodong on 2016/12/17.
//  Copyright © 2016年 duhaodong. All rights reserved.
//

#include "TEST_Filter.h"
#include <stdio.h>
#import <UIKit/UIKit.h>

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavfilter/avfiltergraph.h>
#include <libavfilter/buffersink.h>
#include <libavfilter/buffersrc.h>
#include <libavutil/avutil.h>
#include <libswscale/swscale.h>


#import "PBVideoSwDecoder.h"

static AVFormatContext *pFormatCtx;
static AVCodecContext *pCodecCtx;
AVFilterContext *buffersink_ctx;
AVFilterContext *buffersrc_ctx;
AVFilterGraph *filter_graph;
static int video_stream_index = -1;


@interface myFilter()
{
    dispatch_queue_t playQueue;
    //test log
    float timeSumCost;
    float timeCount;
}

@end
@implementation myFilter

static int open_input_file(const char *filename)
{
    int ret;
    AVCodec *dec;
    
    if ((ret = avformat_open_input(&pFormatCtx, filename, NULL, NULL)) < 0) {
        char buf[1024];
        av_strerror(ret, buf, 1024);
        printf("Couldn't open file %s: %d(%s)", filename, ret, buf);
        
        return ret;
    }
    
    if ((ret = avformat_find_stream_info(pFormatCtx, NULL)) < 0) {
        printf( "Cannot find stream information\n");
        return ret;
    }
    
    /* select the video stream */
    ret = av_find_best_stream(pFormatCtx, AVMEDIA_TYPE_VIDEO, -1, -1, &dec, 0);
    if (ret < 0) {
        printf( "Cannot find a video stream in the input file\n");
        return ret;
    }
    video_stream_index = ret;
    pCodecCtx = pFormatCtx->streams[video_stream_index]->codec;
//    pCodecCtx->flags |= CODEC_FLAG_LOW_DELAY;
    
    /* init the video decoder */
    if ((ret = avcodec_open2(pCodecCtx, dec, NULL)) < 0) {
        printf( "Cannot open video decoder\n");
        return ret;
    }
    
    return 0;
}

static int init_filters(const char *filters_descr)
{
    char args[512];
    int ret;
    AVFilter *buffersrc  = avfilter_get_by_name("buffer");
    AVFilter *buffersink = avfilter_get_by_name("ffbuffersink");
    AVFilterInOut *outputs = avfilter_inout_alloc();
    AVFilterInOut *inputs  = avfilter_inout_alloc();
    enum AVPixelFormat pix_fmts[] = { AV_PIX_FMT_YUV420P, AV_PIX_FMT_NONE };
    AVBufferSinkParams *buffersink_params;
    
    filter_graph = avfilter_graph_alloc();

    /* buffer video source: the decoded frames from the decoder will be inserted here. */
    snprintf(args, sizeof(args),
             "video_size=%dx%d:pix_fmt=%d:time_base=%d/%d:pixel_aspect=%d/%d",
             pCodecCtx->width, pCodecCtx->height, pCodecCtx->pix_fmt,
             pCodecCtx->time_base.num, pCodecCtx->time_base.den,
             pCodecCtx->sample_aspect_ratio.num, pCodecCtx->sample_aspect_ratio.den);
    
    ret = avfilter_graph_create_filter(&buffersrc_ctx, buffersrc, "in", args, NULL, filter_graph);
    if (ret < 0) {
        printf("Cannot create buffer source\n");
        return ret;
    }
    
    /* buffer video sink: to terminate the filter chain. */
    buffersink_params = av_buffersink_params_alloc();
    buffersink_params->pixel_fmts = pix_fmts;
    ret = avfilter_graph_create_filter(&buffersink_ctx, buffersink, "out", NULL, buffersink_params, filter_graph);
    av_free(buffersink_params);
    if (ret < 0)
    {
        printf("Cannot create buffer sink\n");
        return ret;
    }
    
    
    /* Endpoints for the filter graph. */
    outputs->name       = av_strdup("in");
    outputs->filter_ctx = buffersrc_ctx;
    outputs->pad_idx    = 0;
    outputs->next       = NULL;
    
    inputs->name       = av_strdup("out");
    inputs->filter_ctx = buffersink_ctx;
    inputs->pad_idx    = 0;
    inputs->next       = NULL;

    if ((ret = avfilter_graph_parse_ptr(filter_graph, filters_descr, &inputs, &outputs, NULL)) < 0)
        return ret;
    
    if ((ret = avfilter_graph_config(filter_graph, NULL)) < 0)
        return ret;
    return 0;
}

-(int) filterFile:(const char *)inPutFile :( const char* )pngName :(const char*)outPutFile  progress:(void (^)(int32_t per, PBVideoFrame *frame))progress
{
    int ret;
    AVPacket packet;
    AVFrame *pFrame;
    AVFrame *pFrame_out;
    
    int got_frame;
    
    av_register_all();
    avfilter_register_all();
    
    if ((ret = open_input_file(inPutFile)) < 0)
        goto end;
    char filters[1024] = {0};
    sprintf(filters, "movie=%s[wm];[in][wm]overlay=5:5[out]", pngName);

    if ((ret = init_filters(filters)) < 0)
        goto end;
    
    FILE *fp_yuv=fopen(outPutFile,"wb+");

    
    pFrame=av_frame_alloc();
    pFrame_out=av_frame_alloc();
    
    /* read all packets */
    while (1) {
        
        ret = av_read_frame(pFormatCtx, &packet);
        if (ret< 0)
            break;
        
        if (packet.stream_index == video_stream_index) {
            got_frame = 0;
            ret = avcodec_decode_video2(pCodecCtx, pFrame, &got_frame, &packet);
            if (ret < 0) {
                printf( "Error decoding video\n");
                break;
            }
            
            if (got_frame) {
                pFrame->pts = av_frame_get_best_effort_timestamp(pFrame);
                
                /* push the decoded frame into the filtergraph */
                if (av_buffersrc_add_frame(buffersrc_ctx, pFrame) < 0) {
                    printf( "Error while feeding the filtergraph\n");
                    break;
                }
                
                /* pull filtered pictures from the filtergraph */
                while (1) {
                    
                    ret = av_buffersink_get_frame(buffersink_ctx, pFrame_out);
                    if (ret < 0)
                        break;
    
                    printf("Process 1 frame!\n");
                    if(progress)
                    {
                        
                        PBVideoFrame *pvFrame = [self getVideoFrme:pFrame_out :pFrame_out->width :pFrame_out->height];
                        
                        progress(1, pvFrame);
                    }
                    
                    if (pFrame_out->format==AV_PIX_FMT_YUV420P)
                    {
                        //Y, U, V
                        for(int i=0;i<pFrame_out->height;i++){
                            fwrite(pFrame_out->data[0]+pFrame_out->linesize[0]*i,1,pFrame_out->width,fp_yuv);
                        }
                        for(int i=0;i<pFrame_out->height/2;i++){
                            fwrite(pFrame_out->data[1]+pFrame_out->linesize[1]*i,1,pFrame_out->width/2,fp_yuv);
                        }
                        for(int i=0;i<pFrame_out->height/2;i++){
                            fwrite(pFrame_out->data[2]+pFrame_out->linesize[2]*i,1,pFrame_out->width/2,fp_yuv);
                        }
                    }
                    av_frame_unref(pFrame_out);
                }
            }
            av_frame_unref(pFrame);
        }
        av_free_packet(&packet);
    }
    fclose(fp_yuv);
    
end:
    avfilter_graph_free(&filter_graph);
    if (pCodecCtx)
        avcodec_close(pCodecCtx);
    if (pFormatCtx)
        avformat_close_input(&pFormatCtx);
    
    
    if (ret < 0 && ret != AVERROR_EOF) {
        char buf[1024];
        av_strerror(ret, buf, sizeof(buf));
        printf("Error occurred: %s\n", buf);  
        return -1;  
    }  
    
    return 0;  
}


-(int) playFile:(const char*)inPutFile progress:(void(^)(int per, PBVideoFrame*frame))progress
{
    playQueue = dispatch_queue_create("playqueu", DISPATCH_QUEUE_SERIAL);
    dispatch_async(playQueue, ^{
        char fileName[1024] = {0};
        memcpy(fileName, inPutFile, strlen(inPutFile));
        [self doPlayFile:fileName progress:progress];
    });
    return 0;
}

-(int)doPlayFile:(const char*)inPutFile progress:(void(^)(int per, PBVideoFrame*frame))progress
{
    int ret;
    AVPacket packet;
    AVFrame *pFrame;
    AVFrame *pFrame_out;
    
    int got_frame;
    
    av_register_all();
    avfilter_register_all();
    
    if ((ret = open_input_file(inPutFile)) < 0)
        goto end;
    char filters[1024] = {0};
    
    
    pFrame=av_frame_alloc();
    NSTimeInterval curTime = [[NSDate date]timeIntervalSince1970];
    while (!self.cancel) {
        ret = av_read_frame(pFormatCtx, &packet);
        if (ret< 0)
            break;
        
        if (packet.stream_index == video_stream_index) {
            got_frame = 0;
            NSTimeInterval time = [[NSDate date]timeIntervalSince1970];
            ret = avcodec_decode_video2(pCodecCtx, pFrame, &got_frame, &packet);
            
            NSTimeInterval cost = [[NSDate date]timeIntervalSince1970] - time;
            //    printf("decode cost time:%.3f\n", cost);
            if (timeCount++ < 50) {
                timeSumCost += cost;
            }
            else{
                printf("decode W:%d H:%d  avg cost :%.3f\n", pFrame->width, pFrame->height, timeSumCost / timeCount);
                timeCount = 0;
                timeSumCost = 0;
            }
            if (ret < 0) {
                printf( "Error decoding video\n");
                break;
            }
            
            if (got_frame) {
                pFrame->pts = av_frame_get_best_effort_timestamp(pFrame);
                
                PBVideoFrame *pvFrame = [self getVideoFrme:pFrame :pFrame->width :pFrame->height];
//                dispatch_async(dispatch_get_main_queue(), ^{
                    progress(1,pvFrame);
//                });
            }
        }
    }
    
end:
    if (pCodecCtx)
        avcodec_close(pCodecCtx);
    if (pFormatCtx)
        avformat_close_input(&pFormatCtx);
    
    if (ret < 0 && ret != AVERROR_EOF) {
        char buf[1024];
        av_strerror(ret, buf, sizeof(buf));
        printf("Error occurred: %s\n", buf);  
        return -1;  
    }  
    
    return 0;
}

-(void)cancelPaly
{
    self.cancel = YES;
}
-(PBVideoFrame*)getVideoFrme:(AVFrame*)avFrame :(int)vwidth :(int)vheight
{
    static  char *yuvBuffer;
    if(!yuvBuffer)
    {
        yuvBuffer = (unsigned char *)malloc(1024*1024*3 * 10);
    }
    unsigned char *bufferOffset = yuvBuffer;
    
    int dataLength = 0;
    
    int width = MIN(avFrame->linesize[0], vwidth);
    int size = width * vheight;
    memcpy(yuvBuffer, avFrame->data[0], size);
    bufferOffset += size;
    dataLength += size;
    
    width = MIN(avFrame->linesize[1], vwidth/2);
    size = width * (vheight / 2);
    memcpy(bufferOffset, avFrame->data[1],size);
    bufferOffset += size;
    dataLength += size;
    
    width = MIN(avFrame->linesize[2], vwidth/2);
    size = width *(vheight / 2);
    memcpy(bufferOffset, avFrame->data[2],size);
    bufferOffset += size;
    dataLength += size;
    
    PBVideoFrame *pvFrame = [[PBVideoFrame alloc]init];
    
    pvFrame.videoData = (unsigned char *)malloc(dataLength);//yuvBuffer;
    memcpy(pvFrame.videoData, yuvBuffer, dataLength);
    pvFrame.dataLength = dataLength;
    pvFrame.width = vwidth;
    pvFrame.height = vheight;
    
    
    return pvFrame;
}

@end
