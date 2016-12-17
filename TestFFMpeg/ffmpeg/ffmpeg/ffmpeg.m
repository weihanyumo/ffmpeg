//
//  ffmpeg.m
//  ffmpeg
//
//  Created by duhaodong on 16/8/11.
//  Copyright © 2016年 duhaodong. All rights reserved.
//

#import "ffmpeg.h"

#import "avformat.h"
#import "avcodec.h"
#import "PBVideoSwDecoder.h"

#define WRITE_MP4 1

@interface ffmpeg()
{
    int preNeedChangeFlagV;
    int preNeedChangeFlagA;
}

@end
@implementation ffmpeg

- (void)doHlsToMP4:(NSString *)inputPath outputPath:(NSString *)outputPath progress:(void (^)(int32_t, PBVideoFrame *frame))progress
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"%@", outputPath);
        [self download:inputPath outputPath:outputPath progress:progress];
    });
}

- (void)download:(NSString *)inputPath outputPath:(NSString *)outputPath progress:(void (^)(int32_t, PBVideoFrame *frame))progress
{
    PBVideoSwDecoder *decoder = [[PBVideoSwDecoder alloc]initWithDelegate:NULL];
   
    AVOutputFormat *ofmt = NULL;
    AVFormatContext *ifmt_ctx = NULL, *ofmt_ctx = NULL;
    AVPacket pkt;
    int ret, readFrameRet, i;
    
    int32_t total_millis;
    unsigned int percent, last_percent;
    int64_t first_out_ts[2] = {0};
    int64_t prePts[2] = {0};
    int64_t deltaPts[2] = {0};
    int64_t preDts[2] = {0};
    int64_t deltaDts[2] = {0};
    int anomalyDelta = 10000000;
    
    if (!inputPath || !outputPath)
    {
        if (progress)
        {
            progress(-1, NULL);
        }
        return;
    }
    
    av_register_all();
    avformat_network_init();
    
    if ((ret = avformat_open_input(&ifmt_ctx, [inputPath UTF8String], 0, 0)) < 0)
    {
    
        goto end;
    }
    if ((ret = avformat_find_stream_info(ifmt_ctx, 0)) < 0)
    {
    
        goto end;
    }
    av_dump_format(ifmt_ctx, 0, [inputPath UTF8String], 0);
    
    avformat_alloc_output_context2(&ofmt_ctx, NULL, NULL, [outputPath UTF8String]);
    if (!ofmt_ctx)
    {
        ret = AVERROR_UNKNOWN;
        goto end;
    }
    ofmt = ofmt_ctx->oformat;
    for (i = 0; i < ifmt_ctx->nb_streams; i++)
    {
        AVStream *in_stream = ifmt_ctx->streams[i];
        AVStream *out_stream = avformat_new_stream(ofmt_ctx, in_stream->codec->codec);
        if (!out_stream)
        {
            ret = AVERROR_UNKNOWN;
            goto end;
        }
        if ((ret = avcodec_copy_context(out_stream->codec, in_stream->codec)) < 0)
        {
            goto end;
        }
        out_stream->codec->codec_tag = 0;
        if (ofmt_ctx->oformat->flags & AVFMT_GLOBALHEADER)
        {
            out_stream->codec->flags |= CODEC_FLAG_GLOBAL_HEADER;
        }
    }
    
    av_dump_format(ofmt_ctx, 0, [outputPath UTF8String], 1);
    
    if (!(ofmt->flags & AVFMT_NOFILE))
    {
        ret = avio_open(&ofmt_ctx->pb, [outputPath UTF8String], AVIO_FLAG_WRITE);
        if (ret < 0)
        {
            goto end;
        }
    }
    
    AVBitStreamFilterContext* aacbsfc =  av_bitstream_filter_init("aac_adtstoasc");
    total_millis = (int32_t)((ifmt_ctx->duration*1000)/AV_TIME_BASE);
    
    if ((ret = avformat_write_header(ofmt_ctx, NULL)) < 0)
    {
        goto end;
    }
    
    last_percent = 0;
    percent = 0;
    if (progress)
    {
        progress(0, NULL);
    }
    while (true)
    {
        AVStream *in_stream, *out_stream;
        readFrameRet = av_read_frame(ifmt_ctx, &pkt);
        if (readFrameRet < 0)
        {
            if (progress)
            {
                progress(100, NULL);
            }
            break;
        }
        in_stream  = ifmt_ctx->streams[pkt.stream_index];
        out_stream = ofmt_ctx->streams[pkt.stream_index];
        
        av_bitstream_filter_filter(aacbsfc, out_stream->codec, NULL, &pkt.data, &pkt.size, pkt.data, pkt.size, 0);
        
        //edit ts
        if (first_out_ts[pkt.stream_index] == 0)
        {
            first_out_ts[pkt.stream_index] = pkt.pts;
        }
        
        pkt.pts += deltaPts[pkt.stream_index];
        pkt.dts += deltaDts[pkt.stream_index];
        
        BOOL needChange = NO;
        if(prePts[pkt.stream_index] >= pkt.pts)// || pkt.needChangeTS)
        {
            needChange = YES;
        }
        if (prePts[pkt.stream_index] != 0 && pkt.pts > (prePts[pkt.stream_index] + anomalyDelta) )
        {
            needChange = YES;
        }
        if(needChange)
        {
            deltaPts[pkt.stream_index] = prePts[pkt.stream_index] - pkt.pts;
            deltaDts[pkt.stream_index] = preDts[pkt.stream_index] - pkt.dts;
            
            pkt.pts = prePts[pkt.stream_index] + pkt.duration / 2 + 10;
            pkt.dts = preDts[pkt.stream_index] + pkt.duration / 2 + 10;
        }
        //        printf("stIndex:%d originPts:%lld writePts:%lld Dts:%lld\n", pkt.stream_index, pkt.pts, pkt.pts - first_out_ts[pkt.stream_index], pkt.dts - first_out_ts[pkt.stream_index]);
        prePts[pkt.stream_index] = pkt.pts;
        preDts[pkt.stream_index] = pkt.dts;
        
        if (pkt.stream_index == 0)
        {
            percent = (unsigned int)((pkt.pts - in_stream->start_time)*1000*100/in_stream->time_base.den)/total_millis;
      
            if ((percent >= last_percent) && (percent < 100))
            {
                if (progress)
                {
                    PBVideoFrame *pvFrame = [decoder decodePackeg:&pkt];
                    progress(percent, pvFrame);//TODO
                }
            }
            else if((percent > last_percent) && (percent >= 100))
            {
                if (progress)
                {
                    progress(99, NULL);
                }
            }
            last_percent = percent;
        }
        pkt.pts = av_rescale_q_rnd(pkt.pts - first_out_ts[pkt.stream_index], in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX);
        pkt.dts = av_rescale_q_rnd(pkt.dts - first_out_ts[pkt.stream_index], in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX);
        pkt.duration = (int32_t)av_rescale_q(pkt.duration, in_stream->time_base, out_stream->time_base);
        pkt.pos = -1;
        if (pkt.dts > pkt.pts || pkt.dts < 0)
        {
            av_free_packet(&pkt);
            continue;
        }
        if ((ret = av_interleaved_write_frame(ofmt_ctx, &pkt)) < 0)
        {
            if (progress)
            {
                progress(-1, NULL);
            }
            break;
        }
        //speed
        _speed += pkt.size;
        _fileSize += pkt.size;
        av_free_packet(&pkt);
        
        if (_isCancelled)
        {
            break;
        }
    }
    av_write_trailer(ofmt_ctx);
end:
    if (ret < 0)
    {
        if (progress)
        {
            progress(-1,NULL);
        }
    }
    if (ifmt_ctx != NULL)
    {
        avformat_close_input(&ifmt_ctx);
    }
    if (ofmt_ctx && !(ofmt->flags & AVFMT_NOFILE))
    {
        avio_close(ofmt_ctx->pb);
    }
    if (ofmt_ctx != NULL)
    {
        avformat_free_context(ofmt_ctx);
    }
    
    return;
}

- (void)cancelDownload
{
    self.isCancelled = YES;
}


@end
