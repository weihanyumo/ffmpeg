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

@interface ffmpeg()
{
    int preNeedChangeFlagV;
    int preNeedChangeFlagA;
}

@end
@implementation ffmpeg

- (void)doHlsToMP4:(NSString *)inputPath outputPath:(NSString *)outputPath progress:(void (^)(int32_t))progress
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self download:inputPath outputPath:outputPath progress:progress];
    });
}

- (void)download:(NSString *)inputPath outputPath:(NSString *)outputPath progress:(void (^)(int32_t))progress
{
    preNeedChangeFlagV = 0;
    preNeedChangeFlagA = 0;
    self.isCancelled = NO;
    AVOutputFormat *ofmt = NULL;
    AVFormatContext *ifmt_ctx = NULL, *ofmt_ctx = NULL;
    AVPacket pkt;
    int ret, readFrameRet, i;
    int frame_index=0;
    
    int videoIndex = -1;
    int audioIndex = -1;
    int32_t total_millis;
    unsigned int percent, last_percent;
    long long preAudioTS = 0;
    long long preVideoTS = 0;
    int64_t first_out_stream_ts_video = 0;
    int64_t first_out_stream_ts_audio = 0;
    if (!inputPath || !outputPath)
    {
        if (progress)
        {
            progress(-1);
        }
        return;
    }
    
    av_register_all();
    avformat_network_init();
    //Input
    if ((ret = avformat_open_input(&ifmt_ctx, [inputPath UTF8String], 0, 0)) < 0) {
        printf( "Could not open input file.");
        goto end;
    }
    if ((ret = avformat_find_stream_info(ifmt_ctx, 0)) < 0) {
        printf( "Failed to retrieve input stream information");
        goto end;
    }
    av_dump_format(ifmt_ctx, 0, [inputPath UTF8String], 0);
    //Output
    avformat_alloc_output_context2(&ofmt_ctx, NULL, NULL, [outputPath UTF8String]);
    if (!ofmt_ctx) {
        printf( "Could not create output context\n");
        ret = AVERROR_UNKNOWN;
        goto end;
    }
    ofmt = ofmt_ctx->oformat;
    
    for (i = 0; i < ifmt_ctx->nb_streams; i++) {
        //Create output AVStream according to input AVStream
        AVStream *in_stream = ifmt_ctx->streams[i];
        AVStream *out_stream = avformat_new_stream(ofmt_ctx, in_stream->codec->codec);
        if (!out_stream) {
            printf( "Failed allocating output stream\n");
            ret = AVERROR_UNKNOWN;
            goto end;
        }
        //Copy the settings of AVCodecContext
        if ((ret = avcodec_copy_context(out_stream->codec, in_stream->codec)) < 0) {
            printf( "Failed to copy context from input to output stream codec context\n");
            goto end;
        }
        out_stream->codec->codec_tag = 0;
        if (ofmt_ctx->oformat->flags & AVFMT_GLOBALHEADER)
            out_stream->codec->flags |= CODEC_FLAG_GLOBAL_HEADER;
        
        if(ifmt_ctx->streams[i]->codec->codec_type == AVMEDIA_TYPE_AUDIO && audioIndex == -1)
        {
            audioIndex = i;
        }
        else if(ifmt_ctx->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO && videoIndex == -1)
        {
            videoIndex = i;
        }
    }
    //Output information------------------
    av_dump_format(ofmt_ctx, 0, [outputPath UTF8String], 1);
    //Open output file
    if (!(ofmt->flags & AVFMT_NOFILE)) {
        ret = avio_open(&ofmt_ctx->pb, [outputPath UTF8String], AVIO_FLAG_WRITE);
        if (ret < 0) {
            printf( "Could not open output file '%s'", [outputPath UTF8String]);
            goto end;
        }
    }
    
    AVBitStreamFilterContext* aacbsfc =  av_bitstream_filter_init("aac_adtstoasc");
    total_millis = (int32_t)((ifmt_ctx->duration*1000)/AV_TIME_BASE);
    
    //Write file header
    if ((ret = avformat_write_header(ofmt_ctx, NULL)) < 0) {
        printf( "Error occurred when opening output file\n");
        goto end;
    }
    
    last_percent = 0;
    percent = 0;
    if (progress) {
        progress(0);
    }
    
    
    AVDictionary *dict = ifmt_ctx->programs[0]->metadata;
    AVFrame *pFrame = avcodec_alloc_frame();
    int got_picture = 0;
    AVCodecContext* video_dec_ctx = ifmt_ctx->streams[0]->codec;
    AVCodec *video_dec = avcodec_find_decoder(video_dec_ctx->codec_id);
    if (avcodec_open2(video_dec_ctx, video_dec, NULL) < 0)
    {
        NSLog(@"no codec");
    }
    
    while (true) {
        AVStream *in_stream, *out_stream;
        //Get an AVPacket
        readFrameRet = av_read_frame(ifmt_ctx, &pkt);
        if (readFrameRet < 0){
            if (progress) {
                progress(100);
            }
            break;
        }
        in_stream  = ifmt_ctx->streams[pkt.stream_index];
        out_stream = ofmt_ctx->streams[pkt.stream_index];
        
        av_bitstream_filter_filter(aacbsfc, out_stream->codec, NULL, &pkt.data, &pkt.size, pkt.data, pkt.size, 0);
        if (pkt.stream_index == videoIndex)
        {
//            printf("stream_index:%1d dts:%8lld pts:%8lld delta:%lld in_stream.start_time:%8lld pktPos:%lld, duration:%d\n", pkt.stream_index, pkt.dts, pkt.pts, pkt.pts - preVideoTS, in_stream->start_time, pkt.pos, pkt.duration);
            
            ///
            ret = avcodec_decode_video2(video_dec_ctx, pFrame, &got_picture, &pkt);
            ///
            
            
            percent = (unsigned int)((pkt.pts - in_stream->start_time)*1000*100/in_stream->time_base.den)/total_millis;
//            printf("\npercentXXX: %d\n", percent);
            if ((percent > last_percent) && (percent < 100)) {
                if (progress) {
                    progress(percent);
                }
            }else if((percent > last_percent) && (percent >= 100)){
                if (progress) {
                    progress(99);
                }
            }
            last_percent = percent;
        }
        else
        {
//            printf("stream_index:%1d dts:%8lld pts:%8lld delta:%lld in_stream.start_time:%8lld pktPos:%lld, duration:%d\n", pkt.stream_index, pkt.dts, pkt.pts, pkt.pts - preAudioTS, in_stream->start_time, pkt.pos, pkt.duration);
        }
        
        //speed
        _speed += pkt.size;
        _fileSize += pkt.size;
        
        //Convert PTS/DTS
        //start from 0
        
        if(pkt.stream_index == audioIndex)
        {
            if (first_out_stream_ts_audio == 0)
            {
                first_out_stream_ts_audio = pkt.dts;
            }
            
            long long delta = pkt.dts - preAudioTS;
            if(preAudioTS != 0)
            {
                char *nameTS = pkt.nameTS;
                printf(nameTS);
                printf("\n");
                if(preNeedChangeFlagA != pkt.needChangeTS)
//                if (delta > 266679395)//need to find the flag when changed TS
                {
                    long long preTime = preAudioTS - first_out_stream_ts_audio;
                    
                    first_out_stream_ts_audio = pkt.dts - preTime - pkt.duration;
                }
                preNeedChangeFlagA = pkt.needChangeTS;
            }
            preAudioTS = pkt.dts;
            
            pkt.pts = av_rescale_q_rnd(pkt.pts - first_out_stream_ts_audio, in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX);
            pkt.dts = av_rescale_q_rnd(pkt.dts - first_out_stream_ts_audio, in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX);
            pkt.duration = (int32_t)av_rescale_q(pkt.duration, in_stream->time_base, out_stream->time_base);
            pkt.pos = -1;
            
        }
        else
        {
            if (first_out_stream_ts_video == 0)
            {
                first_out_stream_ts_video = pkt.dts;
            }
            long long delta = pkt.dts - preVideoTS;
            if(preVideoTS != 0)
            {
                if (delta > 266679395)
                {
                    long long preTime = preVideoTS - first_out_stream_ts_video;
                    
                    first_out_stream_ts_video = pkt.dts - preTime - pkt.duration;
                }
            }
            preVideoTS = pkt.dts;
            pkt.pts = av_rescale_q_rnd(pkt.pts - first_out_stream_ts_video, in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX);
            pkt.dts = av_rescale_q_rnd(pkt.dts - first_out_stream_ts_video, in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX);
            pkt.duration = (int32_t)av_rescale_q(pkt.duration, in_stream->time_base, out_stream->time_base);
            pkt.pos = -1;
        }
        if (pkt.dts > pkt.pts)
        {
            av_free_packet(&pkt);
            continue;
        }
        //Write
        if ((ret = av_interleaved_write_frame(ofmt_ctx, &pkt)) < 0) {
            printf("Error muxing packet\n");
            if (progress) {
                progress(-1);
            }
            break;
        }
//        printf("Write %8d frames to output file\n",frame_index);
        av_free_packet(&pkt);
        frame_index++;
        
        if (_isCancelled) {
            break;
        }
    }
    //Write file trailer
    av_write_trailer(ofmt_ctx);
end:
    if (ret < 0) {
        if (progress) {
            progress(-1);
        }
    }
    if (ifmt_ctx != NULL) {
        avformat_close_input(&ifmt_ctx);
    }
    /* close output */
    if (ofmt_ctx && !(ofmt->flags & AVFMT_NOFILE)){
        avio_close(ofmt_ctx->pb);
    }
    if (ofmt_ctx != NULL) {
        avformat_free_context(ofmt_ctx);
    }
    
    return;
}

- (void)cancelDownload
{
    self.isCancelled = YES;
}
@end
