//
//  PrefixHeader.h
//  ffmpeg
//
//  Created by duhaodong on 2016/12/1.
//  Copyright © 2016年 duhaodong. All rights reserved.
//

#ifndef PrefixHeader_h
#define PrefixHeader_h

#if TEST_PREFIX_HEADER
#if TARGET_OS_IPHONE
int g_test = 0x12345678;
#elif TARGET_OS_MAC
#endif

#endif /* PrefixHeader_h */
#endif
