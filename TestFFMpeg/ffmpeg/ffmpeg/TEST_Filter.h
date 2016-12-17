//
//  TEST_Filter.h
//  ffmpeg
//
//  Created by duhaodong on 2016/12/17.
//  Copyright © 2016年 duhaodong. All rights reserved.
//

#ifndef TEST_Filter_h
#define TEST_Filter_h

#include <stdio.h>
#import <Foundation/Foundation.h>
#import "PBVideoSwDecoder.h"

@interface myFilter : NSObject

-(int) filterFile:(const char *)inPutFile :( const char* )pngName :(const char*)outPutFile  progress:(void (^)(int32_t per, PBVideoFrame *frame))progress;
@end


#endif /* TEST_Filter_h */
