//
//  MIDecoder.h
//  ffmpeg
//
//  Created by duhaodong on 2017/8/7.
//  Copyright © 2017年 duhaodong. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "PBVideoSwDecoder.h"

@interface MIDecoder : NSObject

-(id)initWidthCodecID:(int)codecID;
-(int) playFile:(NSString*)inPutFile progress:(void(^)(int per, PBVideoFrame*frame))progress;

@end
