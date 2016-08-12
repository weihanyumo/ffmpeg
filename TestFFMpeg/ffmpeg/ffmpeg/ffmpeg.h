//
//  ffmpeg.h
//  ffmpeg
//
//  Created by duhaodong on 16/8/11.
//  Copyright © 2016年 duhaodong. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ffmpeg : NSObject

@property (nonatomic, assign)NSInteger speed;
@property (nonatomic, assign)NSInteger fileSize;
@property (nonatomic, assign)BOOL      isCancelled;

- (void)doHlsToMP4:(NSString *)inputPath outputPath:(NSString *)outputPath progress:(void (^)(int32_t))progress;

- (void)cancelDownload;
@end
