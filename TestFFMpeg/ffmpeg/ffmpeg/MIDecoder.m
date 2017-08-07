//
//  MIDecoder.m
//  ffmpeg
//
//  Created by duhaodong on 2017/8/7.
//  Copyright © 2017年 duhaodong. All rights reserved.
//

#import "MIDecoder.h"
#import "PBVideoSwDecoder.h"
#import "libmi_h264_dec.h"
#import "libmi_h265_dec.h"
#import "libmi_dec_common.h"

#define MAX_YUV_BUFFER_LENGTH 2688*1520*2

#import <mach/mach_time.h>


typedef int (*pfn_mi_decoder_decodeframe)(MI_DEC_HANDLE hDecoder, ST_MI_DEC_INARGS *pstInArgs, ST_MI_DEC_OUTARGS *pstOutArgs);
@interface MIDecoder ()
{
    
    //test log
    float timeSumCost;
    float timeCount;
    unsigned char *yuvBuffer;
    
    ST_MI_DEC_INIT_PARAM stH264InitParam;;
    MI_DEC_HANDLE hH264Handle;
    ST_MI_DEC_INIT_PARAM stH265InitParam;
    MI_DEC_HANDLE hH265Handle;
    MI_DEC_HANDLE hDecHandle;
    ST_MI_DEC_INARGS stInArgs;
    ST_MI_DEC_OUTARGS stOutArgs;
    EM_MI_DECODER_TYPE eDecoderType;
    pfn_mi_decoder_decodeframe pFunDecodeFrame;
    
}

@end

@implementation MIDecoder

-(id)initWidthCodecID:(int)codecID
{
    self = [super init];
    if (self) {
            [self initDecoder];
        if (codecID == 264) {
            eDecoderType = MI_DECODER_H264;
        }
        else
        {
            eDecoderType = MI_DECODER_H265;
        }
    }
    return self;
}

-(void)initDecoder
{
    hH264Handle = NULL;
    hH265Handle = NULL;
    eDecoderType = MI_DECODER_UNKNOWN;
    pFunDecodeFrame = NULL;
    
    ST_MI_DEC_LIB_VERSION sVer;
    mi_h264decoder_getversion(&sVer);
    mi_h265decoder_getversion(&sVer);
    printf("MI version:%s\n", sVer.sVersion);
    
    stH264InitParam.eThreadType = MI_DEC_MULTI_THREAD;
    stH264InitParam.uiThreadCount = 5;
    stH264InitParam.uiTimeScale = 1000;
    mi_h264decoder_create(&hH264Handle, &stH264InitParam);

    stH265InitParam.eThreadType = MI_DEC_MULTI_THREAD;
    stH265InitParam.uiThreadCount = 4;
    stH265InitParam.uiTimeScale = 1000;
    mi_h265decoder_create(&hH265Handle, &stH265InitParam);
}

- (void) setDecHandle: (NSString *) sPath
{
    BOOL bHave = [sPath hasSuffix: @"h264"];
    eDecoderType = MI_DECODER_UNKNOWN;
    
    if (bHave)
    {
        eDecoderType = MI_DECODER_H264;
        hDecHandle = hH264Handle;
        return;
    }
    
    bHave = [sPath hasSuffix: @"h265"];
    if (bHave)
    {
        eDecoderType = MI_DECODER_H265;
        hDecHandle = hH265Handle;
        return;
    }
}

-(int) playFile:(NSString*)inPutFile progress:(void(^)(int per, PBVideoFrame*frame))progress{
    [self startDecode: inPutFile Progress:progress];
    return 0;
}

- (int) startDecode: (NSString *) sPath Progress:(void(^)(int per, PBVideoFrame*frame))progress
{
    NSError *iError = nil;
    BOOL isDir;
    INT32 iRet = 0;
    UINT8 *pInputStream = NULL, *pStream;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    FILE *fp_in = NULL;
    
    if ([fileManager fileExistsAtPath: sPath isDirectory: &isDir] && !isDir)
    {
        char psFilePath[512] = {0};
        sprintf(psFilePath, "%s", [sPath UTF8String]);
        fp_in = fopen(psFilePath, "rb");
        if (NULL == fp_in)
        {
            return -1;
        }
    }

    [self setDecHandle: sPath];
    
    EM_MI_DECODER_TYPE eType = eDecoderType;
    
    pfn_mi_decoder_decodeframe pFunDecodeFrame = NULL;
    UINT32 iFrameCount=0;
    BOOL8 bStreamEnd = FALSE;
    NSString *type;
    switch (eType)
    {
        case MI_DECODER_H264:
            type = [NSString stringWithFormat: @"H264"];
            pFunDecodeFrame = mi_h264decoder_decodeframe;
            break;
        case MI_DECODER_H265:
            type = [NSString stringWithFormat: @"H265"];
            pFunDecodeFrame = mi_h265decoder_decodeframe;
            break;
        default:
            type = [NSString stringWithFormat: @"UNKNOW"];
            goto exitmain;
            break;
    }
    
    fseek(fp_in, 0, SEEK_END);
    int iFileLen = ftell(fp_in);
    fseek(fp_in, 0, SEEK_SET);
    
    pInputStream = (unsigned char *)malloc(iFileLen);
    
    fread(pInputStream, 1, iFileLen, fp_in);
    pStream = pInputStream;
    
    stInArgs.bTimeLog = FALSE; //TRUE;
    
    // decoding time: start
    uint64_t iStartTime = mach_absolute_time();
    while (!bStreamEnd)
    {
        if (iFrameCount > 0)
        {
            // give last position to decode;
            pStream += stOutArgs.uiBytsConsumed;
            iFileLen -= stOutArgs.uiBytsConsumed;
        }
//        sleep(1);
        
        stInArgs.pStream = pStream;
        stInArgs.uiStreamLen = iFileLen;
        
        stOutArgs.eDecodeStatus = MI_DEC_MAX_NUM;
        stOutArgs.uiBytsConsumed = 0;
        
        NSTimeInterval time = [[NSDate date]timeIntervalSince1970];
        iRet = pFunDecodeFrame(hDecHandle, &stInArgs, &stOutArgs);
        
        NSTimeInterval cost = [[NSDate date]timeIntervalSince1970] - time;
        //    printf("decode cost time:%.3f\n", cost);
        if (timeCount++ < 50) {
            timeSumCost += cost;
        }
        else{
            printf("decode W:%d H:%d  avg cost :%.3f\n", stOutArgs.uiDecWidth, stOutArgs.uiDecHeight, timeSumCost / timeCount);
            timeCount = 0;
            timeSumCost = 0;
        }
        if (iRet != 0)
        {
            if (0 >= iFileLen)
            {
                bStreamEnd = 1;
                break;
            }
        }
        
        // Output YUV420P graphic
        if (stOutArgs.eDecodeStatus == MI_DEC_GETDISPLAY)
        {
            if(!yuvBuffer)
            {
                yuvBuffer = (unsigned char *)malloc(MAX_YUV_BUFFER_LENGTH);
            }
            
            PBVideoFrame *pvFrame = [[PBVideoFrame alloc] init];
            
            int dataLength = 0;
            unsigned char *bufferOffset = yuvBuffer;
            //
            int UVlen = (stOutArgs.uiDecWidth * stOutArgs.uiDecHeight)/4;
            memcpy(bufferOffset + dataLength, stOutArgs.pucOutYUV[0], stOutArgs.uiDecWidth * stOutArgs.uiDecHeight);
            dataLength += stOutArgs.uiDecWidth * stOutArgs.uiDecHeight;
            
            memcpy(bufferOffset + dataLength, stOutArgs.pucOutYUV[1], UVlen);
            dataLength += UVlen;
            
            memcpy(bufferOffset + dataLength, stOutArgs.pucOutYUV[2], UVlen);
            dataLength += UVlen;
            
            pvFrame.videoData = (unsigned char *)malloc(dataLength);//yuvBuffer;
            memcpy(pvFrame.videoData, yuvBuffer, dataLength);
            pvFrame.dataLength = dataLength;
            pvFrame.width = stOutArgs.uiDecWidth;
            pvFrame.height = stOutArgs.uiDecHeight;
            
            progress(1, pvFrame);
            iFrameCount++;
        }
        else if ((stOutArgs.eDecodeStatus == MI_DEC_NEED_MORE_BITS) || (stOutArgs.eDecodeStatus == MI_DEC_NO_PICTURE))
        {
            printf("decode failded ret:%d\n", iRet);
            bStreamEnd = 1;
        }
        else
        {
            printf("decode failded ret:%d\n", iRet);
        }
    }
exitmain:
    printf("decode over!!!!!\n\n\n");
    if (fp_in != NULL)
        fclose(fp_in);
    
    if (pInputStream != NULL)
    {
        free(pInputStream);
        pInputStream = NULL;
    }
    return 0;
}



@end
