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
#import "PBVideoSwDecoder.h"

#import "EAGLView.h"



#define CacheFolder @"cacheFolder"
#define MP4Prefix @"recordFileName"


@interface ViewController ()
@property(nonatomic, strong) ffmpeg     *peg;
@property (nonatomic, strong) IBOutlet UIButton  *btnDownload;
@property (nonatomic, strong) EAGLView *eaglView;
@property (nonatomic, strong) IBOutlet UITextField *textUrl;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self initEAGLView];
    // Do any additional setup after loading the view, typically from a nib.
}

-(void) initEAGLView{
    if (!_eaglView)
    {
        _eaglView = [[EAGLView alloc] init];
        [_eaglView setLayerScale:2.0];
        NSString *myString = @"";
        unsigned char *string = (unsigned char *) [myString UTF8String];
        [_eaglView drawView:string];
    }
    
    //    [_eaglView setLayerScale:[[UIScreen mainScreen] scale]];
    UIView *viewPlayBody = [[UIView alloc]initWithFrame:CGRectMake(0, 400, self.view.frame.size.width, 321)];
    [viewPlayBody setBackgroundColor:[UIColor lightGrayColor]];
    [self.view addSubview:viewPlayBody];
    
    _eaglView.frame = viewPlayBody.bounds;
    _eaglView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_eaglView setDataSize:640 andHeight:480];
    //    [_eaglView addBorderWithColor:[UIColor blueColor] width:3.0 radius:120];
    [viewPlayBody insertSubview:_eaglView atIndex:0];
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
    NSLog(outFile);
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
    NSString *url = @"http://api.xiaoyi.com/v4/cloud/index.m3u8?expire=1476168958&code=D9FFF5680ED248F5022CC9C390A824C7354A7510347D804D2E65712AC8893865FCE3033C00ACEE7945EF439B6BCDF0AA6B673ACB0FA43A390B0E813E6709B2E92826ECE533D9F2B11131FBD871D763AF33BC72B3383FC4A80A45113DE197ED3B&hmac=BIF6T9xwkYmEb2ADKp7WpOtrsX0%3D";
    if (self.textUrl.text.length < 10)
    {
        return;
    }
    else
    {
        url = self. textUrl.text;
    }
    NSString *outFile = [self getFilePath];
    [self.peg doHlsToMP4:url outputPath:outFile progress:^(int32_t val, PBVideoFrame *frame) {
        dispatch_async(dispatch_get_main_queue(), ^{
            int per = val >= 100 ? 100 : val;
            [_btnDownload setTitle:[NSString stringWithFormat:@"%3d%%", per] forState:UIControlStateNormal];
            
            int intWidth = frame.width;
            int intHeight = frame.height;
            [_eaglView setDataSize:intWidth andHeight:intHeight];
            if(frame.videoData)
            {
                [_eaglView drawView:frame.videoData];
            }
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

@end
