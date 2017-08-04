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
#import "TEST_Filter.h"
#import "PBVideoSwDecoder.h"
#import "ffUDP.h"


#import "EAGLView.h"



#define CacheFolder @"cacheFolder"


@interface ViewController ()
@property(nonatomic, strong) ffmpeg     *peg;
@property (nonatomic, strong) IBOutlet UIButton  *btnDownload;
@property (nonatomic, strong) EAGLView *eaglView;
@property (nonatomic, strong) IBOutlet UITextField *textUrl;
@property(nonatomic,strong) myFilter *play;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(keyboardHide:)];
    //设置成NO表示当前控件响应后会传播到其他控件上，默认为YES。
    tapGestureRecognizer.cancelsTouchesInView = NO;
    //将触摸事件添加到当前view
    [self.view addGestureRecognizer:tapGestureRecognizer];
    
    [self initEAGLView];
    // Do any additional setup after loading the view, typically from a nib.
}

-(void)keyboardHide:(UITapGestureRecognizer*)tap{
    [self.view endEditing:YES];
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
}

- (IBAction)btnCancelClicked:(id)sender
{
    [self.peg cancelDownload];
    [self.btnDownload setEnabled:YES];
}

- (IBAction)btnMUXClicked:(id)sender
{
    NSString *outFile = [self getFilePath:@"out.mp4" DelOld:YES];
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
    NSString *url = @"http://api-dogfood.xiaoyi.com/v4/cloud/index.m3u8?expire=1481960094&code=E75D65279B303A2886A726CB71C67CEAEF5C213D2826C975141C44B58FF7D3DCB167BBAC1B851653F49CAB50E5246EA36B673ACB0FA43A390B0E813E6709B2E92826ECE533D9F2B11131FBD871D763AF33BC72B3383FC4A80A45113DE197ED3B&hmac=i4LrF81NLlieZePbInP5sCzfkIM%3D";
    if (self.textUrl.text.length < 10)
    {
        NSLog(@"no file");
    }
    else
    {
        url = self. textUrl.text;
    }
    NSString *outFile = [self getFilePath:@"hls.mp4" DelOld:YES];
    url = [self getFilePath:@"bbb_1280_720.mkv" DelOld:NO];
    [_btnDownload setEnabled:NO];
    [self.peg doHlsToMP4:url outputPath:outFile progress:^(int32_t val, PBVideoFrame *frame) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (val == -1)
            {
                [_btnDownload setTitle:@"Download" forState:UIControlStateNormal];
                [_btnDownload setEnabled:YES];
                return ;
            }
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
    [_btnDownload setEnabled:YES];
}

-(IBAction)FilterClicked:(id)sender
{
    
    NSString *inFile = [self getFilePath:@"spreed_1080.mkv" DelOld:NO];
//    NSString *inFile = [self getFilePath:@"4096_1744.mkv" DelOld:NO];
//    NSString *inFile = [self getFilePath:@"bbb_1280_720.mkv" DelOld:NO];
    
    NSString *outFile = [self getFilePath:@"out.yuv" DelOld:NO];
    NSString *pngName = [self getFilePath:@"filter.png" DelOld:NO];
    
    myFilter *fileter = [[myFilter alloc]init];
   [ fileter filterFile:[inFile UTF8String] :[pngName UTF8String] :[outFile UTF8String] progress:^(int32_t per, PBVideoFrame *frame) {
       int intWidth = frame.width;
       int intHeight = frame.height;
       [_eaglView setDataSize:intWidth andHeight:intHeight];
       if(frame.videoData)
       {
           [_eaglView drawView:frame.videoData];
       }

   }];
}

-(IBAction)playClicked:(id)sender
{
    NSString *filename = _textUrl.text;
    NSString *inFile = [self getFilePath:filename DelOld:NO];
    //真机
    inFile = @"265";
    NSString *path = [[NSBundle mainBundle] pathForResource:filename ofType:@"h265"];
    if(path){
        inFile = path;
    }
    //真机end
    _play = [[myFilter alloc]init];
    [_play playFile:[inFile UTF8String] progress:^(int per, PBVideoFrame *frame) {
        int intWidth = frame.width;
        int intHeight = frame.height;
        [_eaglView setDataSize:intWidth andHeight:intHeight];
        if(frame.videoData)
        {
            [_eaglView drawView:frame.videoData];
        }
    }];
}

-(IBAction)btnStop:(id)sender
{
    [_play cancelPaly];
    _play = nil;
}

-(IBAction)UDPDOWNclicked:(id)sender
{
    NSString *url = @"http://api-dogfood.xiaoyi.com/v4/cloud/index.m3u8?expire=1481960094&code=E75D65279B303A2886A726CB71C67CEAEF5C213D2826C975141C44B58FF7D3DCB167BBAC1B851653F49CAB50E5246EA36B673ACB0FA43A390B0E813E6709B2E92826ECE533D9F2B11131FBD871D763AF33BC72B3383FC4A80A45113DE197ED3B&hmac=i4LrF81NLlieZePbInP5sCzfkIM%3D";
    url = [self getFilePath:@"bbb_1280_720.mkv" DelOld:NO];
    if (self.textUrl.text.length < 10)
    {
        NSLog(@"no file");
    }
    else
    {
        url = self. textUrl.text;
    }
    ffUDP([url UTF8String]);
    
}




-(NSString*)getFilePath:(NSString*)fileName DelOld:(BOOL)delOld
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
                filePath = [self createFile:filePath Name:fileName DelOld:delOld];
            }else{
                filePath = nil;
            }
        }else{
            filePath = [self createFile:filePath Name:fileName DelOld:delOld];
        }
    }
    @catch (NSException *exception) {
        filePath = nil;
    }
    return filePath;
}

-(NSString *)createFile:(NSString*)filePath Name:(NSString*)Name DelOld:(BOOL)delOld
{
    filePath = [filePath stringByAppendingPathComponent:Name];
    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath])
    {
        if ([[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil] == NO) {
            filePath = nil;
        }
    }
    else
    {
        if(delOld)
        {
            [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
            if ([[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil] == NO) {
                filePath = nil;
            }
        }
    }
    return filePath;
}

@end
