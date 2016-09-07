//
//  ViewController.m
//  testFFMpeg
//
//  Created by duhaodong on 16/8/11.
//  Copyright © 2016年 duhaodong. All rights reserved.
//

#import "ViewController.h"
#import "ffmpeg.h"
#import "muxing.h"
#define CacheFolder @"cacheFolder"
#define MP4Prefix @"recordFileName"


@interface ViewController ()
@property(nonatomic, strong) ffmpeg     *peg;
@property (nonatomic, strong) IBOutlet UIButton  *btnDownload;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    int val = hls_need_change_time("abcS01.s");
    int val2 = hls_need_change_time("abcS00.s");
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)btnDownloadClicked:(UIButton *)btn
{
    [self testHLS];
    [btn setEnabled:NO];
}

- (IBAction)btnCancelClicked:(id)sender
{
    [self.peg cancelDownload];
    [self.btnDownload setEnabled:YES];
}

- (IBAction)btnMUXClicked:(id)sender
{
    NSString *outFile = [self getFilePath];
    muxing([outFile UTF8String]);
}
#pragma mark - test

-(ffmpeg*)peg
{
    if (!_peg)
    {
        _peg = [[ffmpeg alloc] init];
    }
    return _peg;
}

- (void)testHLS
{
    NSString *url = @"http://api.xiaoyi.com/v4/cloud/index.m3u8?expire=1470982114&code=AE5BA8BB08764A11E97166108418BA5471C2CC741602FADD33D47A79A5C610B6396C5B72BACE688190C80E49CC433193F327D7867BAE649BEDE8B40422F561ED4B4ACA4C2F73B9FDFC9FDF8D9FA9458453B5120BE5B1F3433D8D91EB60DFF712&hmac=by79v2iTiKWLgMABOelGglYRihg%3D";
    NSString *outFile = [self getFilePath];
    [self.peg doHlsToMP4:url outputPath:outFile progress:^(int32_t val) {
        dispatch_async(dispatch_get_main_queue(), ^{
            int per = val >= 100 ? 100 : val;
            [_btnDownload setTitle:[NSString stringWithFormat:@"%3d%%", per] forState:UIControlStateNormal];
            if (per == 100)
            {
                NSLog(@"download finished!!!");
                [_btnDownload setTitle:@"Download" forState:UIControlStateNormal];
                [_btnDownload setEnabled:YES];
            }
        });
    }];
}

-(NSString*)getFilePath
{
    NSString *filePath = nil;
    @try {
        filePath = NSTemporaryDirectory();
        filePath = [filePath stringByAppendingPathComponent:CacheFolder];
        //不存在则创建
        if (![[NSFileManager defaultManager] fileExistsAtPath:filePath])
        {
            BOOL isSuccess = [[NSFileManager defaultManager] createDirectoryAtPath:filePath withIntermediateDirectories:YES attributes:nil error:nil];
            if (isSuccess == YES)
            {
                filePath = [self createFile:filePath];
            }else{
                filePath = nil;
            }
        }else{
            filePath = [self createFile:filePath];
        }
    }
    @catch (NSException *exception) {
        filePath = nil;
    }
    return filePath;
}

-(NSString *)createFile:(NSString*)filePath
{
    NSString *fileName = [[NSString alloc] initWithFormat:@"%@%d.mp4", MP4Prefix, 1];
    filePath = [filePath stringByAppendingPathComponent:fileName];
    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath])
    {
        if ([[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil] == NO) {
            filePath = nil;
        }
    }
    else
    {
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
        if ([[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil] == NO) {
            filePath = nil;
        }
    }
    return filePath;
}

static int hls_need_change_time(const char *filename)
{
    char *flag = "S01.";
    if (strstr(filename, flag))
    {
        return 1;
    }
    
    return 0;
}
@end
