
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <libavutil/opt.h>
#include <libavutil/mathematics.h>
#include <libavformat/avformat.h>
#include <libswscale/swscale.h>
#include <libswresample/swresample.h>

/* 5 seconds stream duration */
#define STREAM_DURATION   200.0
#define STREAM_FRAME_RATE 25
#define STREAM_NB_FRAMES  ((int)(STREAM_DURATION * STREAM_FRAME_RATE))
#define STREAM_PIX_FMT    AV_PIX_FMT_YUV420P
static int VIDEO_WIDTH = 400;
static int VIDEO_HEIGHT = 200;
static int g_pts = 0;
static int sws_flags = SWS_BICUBIC;

static AVStream *add_stream(AVFormatContext *oc, AVCodec **codec,
                            enum AVCodecID codec_id)
{
    AVCodecContext *c;
    AVStream *st;
    
    *codec = avcodec_find_encoder(codec_id);
    if (!(*codec))
    {
        printf( "Could not find encoder for '%s'\n", avcodec_get_name(codec_id));
        return NULL;
    }
    
    st = avformat_new_stream(oc, *codec);
    if (!st)
    {
        printf("Could not allocate stream\n");
        return NULL;
    }
    st->id = oc->nb_streams-1;
    c = st->codec;
    
    switch ((*codec)->type) {
        case AVMEDIA_TYPE_AUDIO:
        {
            c->sample_fmt  = AV_SAMPLE_FMT_FLTP;
            c->bit_rate    = 64000;
            c->sample_rate = 44100;
            c->channels    = 2;
        }
            break;
        case AVMEDIA_TYPE_VIDEO:
        {
            c->codec_id = codec_id;
            c->bit_rate = 400000;
            c->width    = VIDEO_WIDTH;
            c->height   = VIDEO_HEIGHT;
            c->time_base.den = STREAM_FRAME_RATE;
            c->time_base.num = 1;
            c->gop_size      = 12;
            c->pix_fmt       = STREAM_PIX_FMT;
            if (c->codec_id == AV_CODEC_ID_MPEG2VIDEO)
            {
                c->max_b_frames = 2;
            }
            if (c->codec_id == AV_CODEC_ID_MPEG1VIDEO)
            {
                c->mb_decision = 2;
            }
        }
            break;
        default:
            break;
    }
    if (oc->oformat->flags & AVFMT_GLOBALHEADER)
    {
        c->flags |= CODEC_FLAG_GLOBAL_HEADER;
    }
    
    return st;
}

static float t, tincr, tincr2;
static uint8_t **src_samples_data;
static int       src_samples_linesize;
static int       src_nb_samples;

static int max_dst_nb_samples;
uint8_t **dst_samples_data;
int       dst_samples_linesize;
int       dst_samples_size;

struct SwrContext *swr_ctx = NULL;
struct SwsContext *m_pSwsContext = NULL;

static void open_audio(AVFormatContext *oc, AVCodec *codec, AVStream *st)
{
    AVCodecContext *c;
    int ret;
    
    c = st->codec;
    
    AVDictionary *opts = NULL;
    av_dict_set(&opts, "strict", "experimental", 0);
    ret = avcodec_open2(c, codec, &opts);
    if (ret < 0)
    {
        printf("Could not open audio codec: %s\n", av_err2str(ret));
        return;
    }
    
    t     = 0;
    tincr = 2 * M_PI * 5.0 / c->sample_rate;
    tincr2 = 2 * M_PI * 5.0 / c->sample_rate / c->sample_rate;
    
    src_nb_samples = c->codec->capabilities & CODEC_CAP_VARIABLE_FRAME_SIZE ?
    10000 : c->frame_size;
    
    ret = av_samples_alloc_array_and_samples(&src_samples_data, &src_samples_linesize, c->channels, src_nb_samples, c->sample_fmt, 0);
    if (ret < 0)
    {
        printf("Could not allocate source samples\n");
        return;
    }
    
    if (c->sample_fmt != AV_SAMPLE_FMT_S16)
    {
        swr_ctx = swr_alloc();
        if (!swr_ctx)
        {
            printf( "Could not allocate resampler context\n");
            return;
        }
        av_opt_set_int       (swr_ctx, "in_channel_count",   c->channels,       0);
        av_opt_set_int       (swr_ctx, "in_sample_rate",     c->sample_rate,    0);
        av_opt_set_sample_fmt(swr_ctx, "in_sample_fmt",      AV_SAMPLE_FMT_S16, 0);
        av_opt_set_int       (swr_ctx, "out_channel_count",  c->channels,       0);
        av_opt_set_int       (swr_ctx, "out_sample_rate",    c->sample_rate,    0);
        av_opt_set_sample_fmt(swr_ctx, "out_sample_fmt",     c->sample_fmt,     0);
        
        if ((ret = swr_init(swr_ctx)) < 0) {
            printf("Failed to initialize the resampling context\n");
            return;
        }
    }
    
    max_dst_nb_samples = src_nb_samples;
    ret = av_samples_alloc_array_and_samples(&dst_samples_data, &dst_samples_linesize, c->channels,
                                             max_dst_nb_samples, c->sample_fmt, 0);
    if (ret < 0)
    {
        printf("Could not allocate destination samples\n");
        return;
    }
    dst_samples_size = av_samples_get_buffer_size(NULL, c->channels, max_dst_nb_samples, c->sample_fmt, 0);
}

static void get_audio_frame(int16_t *samples, int frame_size, int nb_channels)
{
    int j, i, v;
    int16_t *q;
    
    q = samples;
    for (j = 0; j < frame_size; j++)
    {
        v = (int)(sin(t) * 10000);
        for (i = 0; i < nb_channels; i++)
            *q++ = v;
        t     += tincr;
        tincr += tincr2;
    }
}

static int write_audio_frame(AVFormatContext *oc, AVStream *st)
{
    AVCodecContext *c;
    AVPacket pkt = { 0 }; // data and size must be 0;
    AVFrame *frame = avcodec_alloc_frame();
    int got_packet, ret, dst_nb_samples;
    
    av_init_packet(&pkt);
    c = st->codec;
    
    get_audio_frame((int16_t *)src_samples_data[0], src_nb_samples, c->channels);
    
    if (swr_ctx)
    {
        dst_nb_samples = av_rescale_rnd(swr_get_delay(swr_ctx, c->sample_rate) + src_nb_samples, c->sample_rate, c->sample_rate, AV_ROUND_UP);
        if (dst_nb_samples > max_dst_nb_samples)
        {
            av_free(dst_samples_data[0]);
            ret = av_samples_alloc(dst_samples_data, &dst_samples_linesize, c->channels, dst_nb_samples, c->sample_fmt, 0);
            if (ret < 0)
                return 0;
            max_dst_nb_samples = dst_nb_samples;
            dst_samples_size = av_samples_get_buffer_size(NULL, c->channels, dst_nb_samples, c->sample_fmt, 0);
        }
        
        ret = swr_convert(swr_ctx, dst_samples_data, dst_nb_samples, (const uint8_t **)src_samples_data, src_nb_samples);
        if (ret < 0)
        {
            printf("Error while converting\n");
            return 0;
        }
    }
    else
    {
        dst_samples_data[0] = src_samples_data[0];
        dst_nb_samples = src_nb_samples;
    }
    
    frame->nb_samples = dst_nb_samples;
    avcodec_fill_audio_frame(frame, c->channels, c->sample_fmt, dst_samples_data[0], dst_samples_size, 0);
    
    ret = avcodec_encode_audio2(c, &pkt, frame, &got_packet);
    if (ret < 0)
    {
        printf("Error encoding audio frame: %s\n", av_err2str(ret));
        return 0;
    }
    
    if (!got_packet)
        return 0;
    
    pkt.stream_index = st->index;
    
    ret = av_interleaved_write_frame(oc, &pkt);
    if (ret != 0) {
        printf( "Error while writing audio frame: %s\n",
               av_err2str(ret));
        return 0;
    }
    avcodec_free_frame(&frame);
    return  1;
}

static void close_audio(AVFormatContext *oc, AVStream *st)
{
    avcodec_close(st->codec);
    av_free(src_samples_data[0]);
    av_free(dst_samples_data[0]);
}

AVStream *audio_st = NULL, *video_st = NULL;
AVCodec *audio_codec = NULL, *video_codec = NULL;

static AVPicture src_picture;
static int frame_count;

static void open_video(AVFormatContext *oc, AVCodec *codec, AVStream *st)
{
    int ret;
    int pts = 0;
    AVCodecContext *c = st->codec;
    
    ret = avcodec_close(c);
    ret = avcodec_open2(c, codec, NULL);
    if (ret < 0)
    {
        printf("Could not open video codec: %s\n", av_err2str(ret));
        return;
    }
    //    if (frame)
    //    {
    //        pts = frame->pts;
    //        av_free(frame);
    //        frame = NULL;
    //    }
    //    frame = avcodec_alloc_frame();
    //    frame->pts = pts;
    //    if (!frame)
    //    {
    //        printf("Could not allocate video frame\n");
    //        return;
    //    }
    //
    //    ret = avpicture_alloc(&dst_picture, c->pix_fmt, c->width, c->height);
    //    if (ret < 0)
    //    {
    //        printf( "Could not allocate picture: %s\n", av_err2str(ret));
    //        return;
    //    }
    //
    //    if (c->pix_fmt != AV_PIX_FMT_YUV420P)
    //    {
    //        ret = avpicture_alloc(&src_picture, AV_PIX_FMT_YUV420P, c->width, c->height);
    //        if (ret < 0)
    //        {
    //            printf( "Could not allocate temporary picture: %s\n", av_err2str(ret));
    //            return;
    //        }
    //    }
    //    *((AVPicture *)frame) = dst_picture;
}

static void fill_yuv_image(AVPicture *pict, int frame_index,
                           int width, int height)
{
    int x, y, i;
    
    i = frame_index;
    
    /* Y */
    for (y = 0; y < height; y++)
        for (x = 0; x < width; x++)
            pict->data[0][y * pict->linesize[0] + x] = x + y + i * 3;
    
    /* Cb and Cr */
    for (y = 0; y < height / 2; y++)
    {
        for (x = 0; x < width / 2; x++)
        {
            pict->data[1][y * pict->linesize[1] + x] = 128 + y + i * 2;
            pict->data[2][y * pict->linesize[2] + x] = 64 + x + i * 5;
        }
    }
}
int ScaleImg(AVCodecContext *pCodecCtx,AVFrame *src_picture,AVFrame *dst_picture,int nDstH ,int nDstW )
{
    int i ;
    int nSrcStride[3];
    int nDstStride[3];
    int nSrcH = pCodecCtx->height;
    int nSrcW = pCodecCtx->width;
    struct SwsContext* m_pSwsContext;
    
    uint8_t *pSrcBuff[3] = {src_picture->data[0],src_picture->data[1], src_picture->data[2]};
    
    nSrcStride[0] = nSrcW ;
    nSrcStride[1] = nSrcW/2 ;
    nSrcStride[2] = nSrcW/2 ;
    
    dst_picture->linesize[0] = nDstW;
    dst_picture->linesize[1] = nDstW / 2;
    dst_picture->linesize[2] = nDstW / 2;
    
    if (nSrcW == nDstW && nSrcH == nDstH)
    {
        return 1;
    }
    printf("nSrcW%d\n",nSrcW);
    
    
    m_pSwsContext = sws_getContext(nSrcW, nSrcH, PIX_FMT_YUV420P,
                                   nDstW, nDstH, PIX_FMT_YUV420P,
                                   SWS_BICUBIC,
                                   NULL, NULL, NULL);
    
    
    if (NULL == m_pSwsContext)
    {
        printf("ffmpeg get context error!\n");
        return -1;
    }
    
    
    sws_scale(m_pSwsContext, src_picture->data,src_picture->linesize, 0, pCodecCtx->height,dst_picture->data,dst_picture->linesize);
    
    
    printf("line0:%d line1:%d line2:%d\n",dst_picture->linesize[0] ,dst_picture->linesize[1] ,dst_picture->linesize[2]);
    sws_freeContext(m_pSwsContext);
    
    
    return 1 ;
}

static void write_video_frame(AVFormatContext *oc, AVStream *st, int w, int h)
{
    int ret;
    static struct SwsContext *sws_ctx;
    AVCodecContext *c = st->codec;
    AVPicture dst_picture, src_picture;
    ret = avpicture_alloc(&src_picture, c->pix_fmt, w, h);
    ret = avpicture_alloc(&dst_picture, c->pix_fmt, w, h);
    AVFrame *frame, *srcFrame;
    
    frame = avcodec_alloc_frame();
    srcFrame = avcodec_alloc_frame();
    
    if (frame_count >= STREAM_NB_FRAMES)
    {
    }
    else
    {
        if (c->pix_fmt != AV_PIX_FMT_YUV420P)
        {
            if (!sws_ctx)
            {
                sws_ctx = sws_getContext(c->width, c->height, AV_PIX_FMT_YUV420P,
                                         c->width, c->height, c->pix_fmt,
                                         sws_flags, NULL, NULL, NULL);
                if (!sws_ctx)
                {
                    printf( "Could not initialize the conversion context\n");
                    exit(1);
                }
            }
            fill_yuv_image(&src_picture, frame_count, c->width, c->height);
            sws_scale(sws_ctx, (const uint8_t * const *)src_picture.data, src_picture.linesize, 0, c->height, dst_picture.data, dst_picture.linesize);
        }
        else
        {
            fill_yuv_image(&src_picture, frame_count, w, h);
            
            *((AVPicture *)srcFrame) = src_picture;
        }
    }
    
    if (oc->oformat->flags & AVFMT_RAWPICTURE)
    {
        AVPacket pkt;
        av_init_packet(&pkt);
        pkt.flags        |= AV_PKT_FLAG_KEY;
        pkt.stream_index  = st->index;
        pkt.data          = dst_picture.data[0];
        pkt.size          = sizeof(AVPicture);
        ret = av_interleaved_write_frame(oc, &pkt);
    }
    else
    {
        AVPacket pkt = { 0 };
        int got_packet;
        av_init_packet(&pkt);
        if (w != VIDEO_WIDTH || h != VIDEO_HEIGHT)
        {
            fill_yuv_image(&dst_picture, frame_count, w, h);
            *((AVPicture *)frame) = dst_picture;
            
            ScaleImg(c, srcFrame, frame, VIDEO_HEIGHT, VIDEO_WIDTH);
            frame->pts = g_pts;
            ret = avcodec_encode_video2(c, &pkt, frame, &got_packet);
        }
        else
        {
            srcFrame->pts = g_pts;
            ret = avcodec_encode_video2(c, &pkt, srcFrame, &got_packet);
        }
        
        if (ret < 0)
        {
            printf("Error encoding video frame:\n");
            frame_count++;
            return;
        }
        
        if (!ret && got_packet && pkt.size)
        {
            pkt.stream_index = st->index;
            ret = av_interleaved_write_frame(oc, &pkt);
        }
        else
        {
            ret = 0;
        }
    }
    if (ret != 0)
    {
        printf( "Error while writing video frame: %s\n", av_err2str(ret));
        return;
    }
    frame_count++;
    
    //    av_free(src_picture.data[0]);
    av_free(dst_picture.data[0]);
    
    av_frame_free(&srcFrame);
    av_frame_free(&frame);
    
}

static void close_video(AVFormatContext *oc, AVStream *st)
{
    avcodec_close(st->codec);
}

void initStreams(AVFormatContext * formatContext)
{
    AVOutputFormat *fmt = formatContext->oformat;
    
    if (fmt->video_codec != AV_CODEC_ID_NONE)
    {
        video_st = add_stream(formatContext, &video_codec, fmt->video_codec);
    }
    if (fmt->audio_codec != AV_CODEC_ID_NONE)
    {
        audio_st = add_stream(formatContext, &audio_codec, fmt->audio_codec);
    }
    
    if (video_st)
    {
        open_video(formatContext, video_codec, video_st);
    }
    if (audio_st)
    {
        open_audio(formatContext, audio_codec, audio_st);
    }
}

void deInit(AVFormatContext* formatContext)
{
    AVOutputFormat *fmt = formatContext->oformat;
    
    if (video_st)
    {
        close_video(formatContext, video_st);
    }
    if (audio_st)
    {
        close_audio(formatContext, audio_st);
    }
    
    if (!(fmt->flags & AVFMT_NOFILE))
    {
        avio_close(formatContext->pb);
    }
    
    avformat_free_context(formatContext);
}

void freeVideoStream(AVFormatContext* formatContext)
{
    if (video_st)
    {
        close_video(formatContext, video_st);
        video_st = NULL;
    }
}

int muxing(char *filename)
{
    AVOutputFormat *fmt;
    AVFormatContext *formatContext;
    double audio_time, video_time;
    int ret;
    
    g_pts = 0;
    
    av_register_all();
    avformat_alloc_output_context2(&formatContext, NULL, NULL, filename);
    if (!formatContext)
    {
        printf("Could not deduce output format from file extension: using MPEG.\n");
        avformat_alloc_output_context2(&formatContext, NULL, "mpeg", filename);
    }
    if (!formatContext) {
        return 1;
    }
    fmt = formatContext->oformat;
    
    initStreams(formatContext);
    
    if (!(fmt->flags & AVFMT_NOFILE))
    {
        ret = avio_open(&formatContext->pb, filename, AVIO_FLAG_WRITE);
        if (ret < 0)
        {
            printf("Could not open '%s': %s\n", filename,
                   av_err2str(ret));
            return 1;
        }
    }
    ret = avformat_write_header(formatContext, NULL);
    if (ret < 0)
    {
        printf( "Error occurred when opening output file: %s\n", av_err2str(ret));
        return 1;
    }
    
    for (;;)
    {
        audio_time = audio_st ? audio_st->pts.val * av_q2d(audio_st->time_base) : 0.0;
        video_time = video_st ? video_st->pts.val * av_q2d(video_st->time_base) : 0.0;
        
        if ((!audio_st || audio_time >= STREAM_DURATION) &&
            (!video_st || video_time >= STREAM_DURATION))
            break;
        
        if (!video_st || (video_st && audio_st && audio_time < video_time))
        {
            write_audio_frame(formatContext, audio_st);
        }
        else
        {
            int w = VIDEO_WIDTH, h = VIDEO_HEIGHT;
            if (frame_count >= 300)
            {
                //                AVCodecContext *c = video_st->codec;
                w = VIDEO_WIDTH/2;
                
                h = VIDEO_HEIGHT/2;
                //
                //                open_video(formatContext, c->codec, video_st);
            }
            write_video_frame(formatContext, video_st, w, h);
            g_pts += av_rescale_q(1, video_st->codec->time_base, video_st->time_base);
        }
    }
    av_write_trailer(formatContext);
    frame_count = 0;
    deInit(formatContext);
    
    return 0;
}





