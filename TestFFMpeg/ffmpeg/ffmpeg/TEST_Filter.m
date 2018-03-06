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

typedef struct
{
    //unsigned int channel; // Camera Index
    unsigned int useCount;
    unsigned char reserved[4];
} testSt;
static int open_input_file(const char *filename)
{
    int ret;
    testSt *commandData =  (testSt *)malloc(sizeof(testSt));
    memset(commandData, 0, sizeof(testSt));
    commandData->useCount = 0x12345678;
    char *firstBit = (char*)commandData;
    int *pint = &commandData->useCount;
    
    firstBit[0] = 1;
    firstBit[1] = 0;
    firstBit[2] = 0;
    firstBit[3] = 0;
    
    commandData->useCount;
    firstBit[3] = 1;
    firstBit[0] = 0;
    
    
    AVCodec *dec;
    char *version = av_version_info();
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
    dec->capabilities |= CODEC_CAP_DELAY;
    video_stream_index = ret;
    pCodecCtx = pFormatCtx->streams[video_stream_index]->codec;
//    pCodecCtx->flags |= CODEC_FLAG_LOW_DELAY;
    
    /* init the video decoder */
    pCodecCtx->thread_type = FF_THREAD_FRAME;
    pCodecCtx->thread_count = 4;
    pCodecCtx->flags |=  CODEC_FLAG2_CHUNKS;
    if ((ret = avcodec_open2(pCodecCtx, dec, NULL)) < 0) {
        printf( "Cannot open video decoder\n");
        return ret;
    }
    int type = pCodecCtx->active_thread_type;
    
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


-(int) playFile:(NSString*)inPutFile progress:(void(^)(int per, PBVideoFrame*frame, NSString*log))progress;
{
    playQueue = dispatch_queue_create("playqueu", DISPATCH_QUEUE_SERIAL);
    dispatch_async(playQueue, ^{
        char fileName[1024] = {0};
        memcpy(fileName, [inPutFile UTF8String], inPutFile.length);
        [self doPlayFile:fileName progress:progress];
    });
    return 0;
}

-(int)doPlayFile:(const char*)inPutFile progress:(void(^)(int per, PBVideoFrame*frame, NSString *log))progress
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
//            [self parserSPS:pCodecCtx->extradata Len:pCodecCtx->extradata_size];
            
            NSTimeInterval cost = [[NSDate date]timeIntervalSince1970] - time;
            //    printf("decode cost time:%.3f\n", cost);
            if (ret < 0) {
                printf( "Error decoding video\n");
                break;
            }
            
            if (got_frame) {
                NSString*delog = nil;
                if (timeCount++ < 50) {
                    timeSumCost += cost;
                }
                else{
                    printf("decode W:%d H:%d  avg cost :%.3f\n", pFrame->width, pFrame->height, timeSumCost / timeCount);
                    delog = [NSString stringWithFormat:@"decode W:%d H:%d  avg cost :%.3f\n", pFrame->width, pFrame->height, timeSumCost / timeCount];
                    timeCount = 0;
                    timeSumCost = 0;
                }
                pFrame->pts = av_frame_get_best_effort_timestamp(pFrame);
                
                PBVideoFrame *pvFrame = [self getVideoFrme:pFrame :pFrame->width :pFrame->height];
//                dispatch_async(dispatch_get_main_queue(), ^{
                    progress(1,pvFrame, delog);
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


//test
-(BOOL)parserSPS:(void *)data Len:(int)dataSize
{
    int width = 0;
    int height = 0;
    
    char buf[1024]=  {0};
    memcpy(buf, data, dataSize);
    long nLen = dataSize;
    
    int start=0;
    int *StartBit = &start;
    //Byte:1
    int forbidden_zero_bit= u(1,buf,StartBit);//[self u:1 Data:buf StartBit:StartBit];// u(1,buf,StartBit);
    int nal_ref_idc= u(2, buf, StartBit);// [self u:2 Data:buf StartBit:StartBit];//u(2,buf,StartBit);
    int nal_unit_type= u(5, buf, StartBit);//[self u:5 Data:buf StartBit:StartBit];//u(5,buf,StartBit);
    if(nal_unit_type==7)
    {
        //Byte:2
        int profile_idc=u(8,buf,StartBit);
        //Byte:3
        int constraint_set0_flag=u(1,buf,StartBit);//(buf[1] & 0x80)>>7;
        int constraint_set1_flag=u(1,buf,StartBit);//(buf[1] & 0x40)>>6;
        int constraint_set2_flag=u(1,buf,StartBit);//(buf[1] & 0x20)>>5;
        int constraint_set3_flag=u(1,buf,StartBit);//(buf[1] & 0x10)>>4;
        int reserved_zero_4bits=u(4,buf,StartBit);
        //Byte:4
        int level_idc=u(8,buf,StartBit);
        
        int seq_parameter_set_id=Ue(buf,nLen,StartBit);
        if( profile_idc == 100 || profile_idc == 110 || profile_idc == 122 || profile_idc == 144 )
        {
            int chroma_format_idc=Ue(buf,nLen,StartBit);
            if( chroma_format_idc == 3 )
            {
                int residual_colour_transform_flag=u(1,buf,StartBit);
            }
            int bit_depth_luma_minus8=Ue(buf,nLen,StartBit);
            int bit_depth_chroma_minus8=Ue(buf,nLen,StartBit);
            int qpprime_y_zero_transform_bypass_flag=u(1,buf,StartBit);
            int seq_scaling_matrix_present_flag=u(1,buf,StartBit);
            
            int seq_scaling_list_present_flag[8];
            if( seq_scaling_matrix_present_flag )
            {
                for( int i = 0; i < 8; i++ )
                {
                    seq_scaling_list_present_flag[i]=u(1,buf,StartBit);
                }
            }
        }
        int log2_max_frame_num_minus4=Ue(buf,nLen,StartBit);
        int pic_order_cnt_type=Ue(buf,nLen,StartBit);
        if( pic_order_cnt_type == 0 )
        {
            int log2_max_pic_order_cnt_lsb_minus4=Ue(buf,nLen,StartBit);
        }
        else if( pic_order_cnt_type == 1 )
        {
            int delta_pic_order_always_zero_flag=u(1,buf,StartBit);
            int offset_for_non_ref_pic=Se(buf,nLen,StartBit);
            int offset_for_top_to_bottom_field=Se(buf,nLen,StartBit);
            int num_ref_frames_in_pic_order_cnt_cycle=Ue(buf,nLen,StartBit);
            int *offset_for_ref_frame=(int*)malloc(num_ref_frames_in_pic_order_cnt_cycle * sizeof(int));//new int[num_ref_frames_in_pic_order_cnt_cycle];
            for( int i = 0; i < num_ref_frames_in_pic_order_cnt_cycle; i++ )
                offset_for_ref_frame[i]=Se(buf,nLen,StartBit);
            free(offset_for_ref_frame);
            offset_for_ref_frame = 0;
        }
        int num_ref_frames=Ue(buf,nLen,StartBit);
        int gaps_in_frame_num_value_allowed_flag=u(1,buf,StartBit);
        
        int pic_width_in_mbs_minus1=Ue(buf,nLen,StartBit);
        
        int pic_height_in_map_units_minus1=Ue(buf,nLen,StartBit);
        width=(pic_width_in_mbs_minus1+1)*16;
        height=(pic_height_in_map_units_minus1+1)*16;
        int frame_mbs_only_flag=u(1,buf,StartBit);
        if(!frame_mbs_only_flag)
        {
            int mb_adaptive_frame_field_flag=u(1,buf,StartBit);
        }
        
        int direct_8x8_inference_flag=u(1,buf,StartBit);
        int frame_cropping_flag=u(1,buf,StartBit);
        if(frame_cropping_flag)
        {
            int frame_crop_left_offset=Ue(buf,nLen,StartBit);
            int frame_crop_right_offset=Ue(buf,nLen,StartBit);
            int frame_crop_top_offset=Ue(buf,nLen,StartBit);
            int frame_crop_bottom_offset=Ue(buf,nLen,StartBit);
            
            width = ((pic_width_in_mbs_minus1 +1)*16) - frame_crop_left_offset*2 - frame_crop_right_offset*2;
            height= ((2 - frame_mbs_only_flag)* (pic_height_in_map_units_minus1 +1) * 16) - (frame_crop_top_offset * 2) - (frame_crop_bottom_offset * 2);
            
        }
        int vui_parameters_present_flag = u(1, buf, StartBit);
        if (vui_parameters_present_flag) {
            int aspect_ratio_idc = u(8, buf, StartBit);
            if (aspect_ratio_idc == 54) {
                int sar_width = u(2, buf, StartBit);
                int sar_height = u(2, buf, StartBit);
                
            }
        }
        
        return true;
    }
    
    return false;
}


uint Ue(char *pBuff, int nLen, int *pStartBit)
{
    //计算0bit的个数
    int nZeroNum = 0;
    while (*pStartBit < nLen * 8)
    {
        char c = pBuff[*pStartBit / 8];
        int c2 = 0x80 >> (*pStartBit % 8);
        
        if (pBuff[*pStartBit / 8] & (0x80 >> (*pStartBit % 8))) //&:按位与，%取余
        {
            break;
        }
        nZeroNum++;
        (*pStartBit)++;
    }
    (*pStartBit)++;
    //计算结果
    uint dwRet = 0;
    for (int i=0; i<nZeroNum; i++)
    {
        dwRet <<= 1;
        char c = pBuff[*pStartBit / 8];
        int c2 = 0x80 >> (*pStartBit % 8);
        if (pBuff[*pStartBit / 8] & (0x80 >> (*pStartBit % 8)))
        {
            dwRet += 1;
        }
        (*pStartBit)++;
    }
    
    return (1 << nZeroNum) - 1 + dwRet;
}

int Se(char *pBuff, int nLen, int *pStartBit)
{
    int UeVal=Ue(pBuff,nLen,pStartBit);
    double k=UeVal;
    //ceil函数：ceil函数的作用是求不小于给定实数的最小整数。ceil(2)=ceil(1.2)=cei(1.5)=2.00
    int nValue = ceil(k/2);
    if (UeVal % 2==0)
        nValue=-nValue;
    
    return nValue;
}

int u(int BitCount, char* buf, int *pStartBit)
{
    short dwRet = 0;
    for (int i=0; i<BitCount; i++)
    {
        dwRet <<= 1;
        char c = buf[*pStartBit / 8];
        int c2 = 0x80 >> (*pStartBit % 8);
        if (buf[*pStartBit / 8] & (0x80 >> (*pStartBit % 8)))
        {
            dwRet += 1;
        }
        (*pStartBit)++;
    }
    return dwRet;
}

@end
