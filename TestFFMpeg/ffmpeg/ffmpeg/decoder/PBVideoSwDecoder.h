//
//  PBVideoSwDecoder.h
//  VoIPBase
//
//  Created by 李油 on 8/12/15.
//  使用ffmpeg软解码
//  PBVideoSwDecoder.h(Sw = software)
//  Copyright (c) 2015 huanghua. All rights reserved.
//

//#import "avcodec.h"


@interface PBVideoFrame : NSObject

@property(assign)char *videoData;
@property(assign)int dataLength;
@property(assign)int width;
@property(assign)int height;

@end

@interface PBVideoSwDecoder : NSObject
-(id)initWithDelegate:(id)aDelegate;
-(PBVideoFrame *)decodePackeg:(void *)packet;
@end

