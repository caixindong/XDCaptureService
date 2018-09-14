//
//  XDViewController.m
//  XDCaptureService
//
//  Created by 458770054@qq.com on 01/29/2018.
//  Copyright (c) 2018 458770054@qq.com. All rights reserved.
//

#import "XDViewController.h"
#import "XDCaptureService.h"
#import <AVKit/AVKit.h>

@interface XDViewController ()<XDCaptureServiceDelegate>
@property (weak, nonatomic) IBOutlet UIView *contentView;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *label;
@property (weak, nonatomic) IBOutlet UILabel *recordstate;
@property (nonatomic, strong) XDCaptureService *service;
@end

@implementation XDViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    _service = [[XDCaptureService alloc] init];
    _service.delegate = self;
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_showDetail)];
    _imageView.userInteractionEnabled = YES;
    [_imageView addGestureRecognizer:tap];
}

- (void)_showDetail {
    if ([_label.text isEqualToString:@"Photo"]) {
        
    } else if ([_label.text isEqualToString:@"Video"]) {
        AVPlayerViewController *avVC = [[AVPlayerViewController alloc] init];
        avVC.player = [AVPlayer playerWithURL:_service.recordURL];
        avVC.videoGravity = AVLayerVideoGravityResizeAspect;
        [avVC.player play];
        avVC.title = @"XDCaptureService Demo";
        [self.navigationController pushViewController:avVC animated:YES];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [_service startRunning];
}

- (void)viewWillDisappear:(BOOL)animated {
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (IBAction)switchCamera:(id)sender {
    [_service switchCamera];
}

- (IBAction)startRecord:(id)sender {
    [_service startRecording];
    _recordstate.hidden = NO;
}

- (IBAction)stopRecord:(id)sender {
    _recordstate.hidden = YES;
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"停止录像" message:nil delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
    [alert show];
    [_service stopRecording];
}
- (IBAction)takePhoto:(id)sender {
    [_service capturePhoto];
}

//service生命周期
- (void)captureServiceDidStartService:(XDCaptureService *)service {
    NSLog(@"captureServiceDidStartService");
}

- (void)captureService:(XDCaptureService *)service serviceDidFailWithError:(NSError *)error {
    NSLog(@"serviceDidFailWithError:%@",error.localizedDescription);
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:error.localizedDescription message:nil delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
    [alert show];
}

- (void)captureServiceDidStopService:(XDCaptureService *)service {
    NSLog(@"captureServiceDidStopService");
}

- (void)captureService:(XDCaptureService *)service getPreviewLayer:(AVCaptureVideoPreviewLayer *)previewLayer {
    if (previewLayer) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_contentView.layer addSublayer:previewLayer];
            previewLayer.frame = _contentView.bounds;
        });
    }
}

- (void)captureService:(XDCaptureService *)service outputSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    
}

//录像相关
- (void)captureServiceRecorderDidStart:(XDCaptureService *)service {
    NSLog(@"captureServiceRecorderDidStart");
}

- (void)captureService:(XDCaptureService *)service recorderDidFailWithError:(NSError *)error {
    NSLog(@"recorderDidFailWithError:%@",error.localizedDescription);
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:error.localizedDescription message:nil delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
    [alert show];
}

- (void)captureServiceRecorderDidStop:(XDCaptureService *)service {
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:service.recordURL options:nil];
    AVAssetImageGenerator *assetGen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    assetGen.appliesPreferredTrackTransform = YES;
    CMTime time = CMTimeMakeWithSeconds(0.0, 600);
    CMTime actualTime;
    CGImageRef img = [assetGen copyCGImageAtTime:time actualTime:&actualTime error:nil];
    UIImage *image = [[UIImage alloc] initWithCGImage:img];
    CGImageRelease(img);
    dispatch_async(dispatch_get_main_queue(), ^{
        _imageView.image = image;
        _label.text = @"Video";
    });
}

//照片捕获
- (void)captureService:(XDCaptureService *)service capturePhoto:(UIImage *)photo {
    dispatch_async(dispatch_get_main_queue(), ^{
        _imageView.image = photo;
        _label.text = @"Photo";
    });
}
@end
