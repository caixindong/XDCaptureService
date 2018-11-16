//
//  XDCaptureService.m
//  XDCaptureService
//
//  Created by 蔡欣东 on 2018/2/26.
//

#import "XDCaptureService.h"
#import "XDVideoWritter.h"
#import <sys/sysctl.h>
#include <mach/mach_time.h>

static NSString *const XDCVIDEODIR = @"tmpVideo";

#define XDCAPTURE_ISIHPNEX [UIScreen mainScreen].bounds.size.height == 812? YES:NO

@interface XDCaptureService()<AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate,XDVideoWritterDelegate,AVCaptureMetadataOutputObjectsDelegate>{
    BOOL _firstStartRunning;
    BOOL _startSessionOnEnteringForeground;
    NSString *_videoDir;
}

@property (nonatomic, strong) AVCaptureSession *captureSession;

@property (nonatomic, strong) dispatch_queue_t sessionQueue;

@property (nonatomic, strong) dispatch_queue_t writtingQueue;

@property (nonatomic, strong) dispatch_queue_t outputQueue;

@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

@property (nonatomic, strong) AVCaptureDevice *currentDevice;

@property (nonatomic, strong) AVCaptureDeviceInput *videoInput;

@property (nonatomic, strong) AVCaptureDeviceInput *audioInput;

@property (nonatomic, strong) AVCaptureVideoDataOutput *videoOutput;

@property (nonatomic, strong) AVCaptureAudioDataOutput *audioOutput;

@property (nonatomic, strong) AVCaptureConnection *videoConnection;

@property (nonatomic, strong) AVCaptureConnection *audioConnection;

@property (nonatomic, strong) NSDictionary *audioSetting;

@property (nonatomic, strong) AVCaptureMetadataOutput *metadataOutput;

@property (nonatomic, strong) AVCaptureStillImageOutput *imageOutput;

@property (nonatomic, strong) XDVideoWritter *videoWriter;

@end

@implementation XDCaptureService

+ (BOOL)videoGranted {
    if ([[UIDevice currentDevice].systemVersion doubleValue] >= 7.0) {
        AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
        if(authStatus == AVAuthorizationStatusDenied){
            return NO;
        }
    }
    return YES;
}

+ (BOOL)audioGranted {
    if ([[UIDevice currentDevice].systemVersion doubleValue] >= 7.0) {
        AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
        if(authStatus == AVAuthorizationStatusDenied){
            return NO;
        }
    }
    return YES;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _sessionQueue = dispatch_queue_create("com.caixindong.captureservice.session", DISPATCH_QUEUE_SERIAL);
        _writtingQueue = dispatch_queue_create("com.caixindong.captureservice.writting", DISPATCH_QUEUE_SERIAL);
        _outputQueue = dispatch_queue_create("com.caixindong.captureservice.output", DISPATCH_QUEUE_SERIAL);
        _shouldRecordAudio = NO;
        _firstStartRunning = NO;
        _isRunning = NO;
        _startSessionOnEnteringForeground = NO;
        _openNativeFaceDetect = NO;
        _devicePosition = AVCaptureDevicePositionFront;
        _videoDir = [NSTemporaryDirectory() stringByAppendingPathComponent:XDCVIDEODIR];
        _sessionPreset = AVCaptureSessionPreset640x480;
        _openDepth = NO;
        _frameRate = 30;
        NSDictionary *compressionProperties = @{
                                                AVVideoAverageBitRateKey : @(640 * 480 * 2.1),
                                                AVVideoExpectedSourceFrameRateKey : @(30),
                                                AVVideoMaxKeyFrameIntervalKey : @(30),
                                                AVVideoProfileLevelKey:AVVideoProfileLevelH264Main41,
                                                };
        
        //宽高的设置影响录出来视频的尺寸
        _videoSetting = @{
                          AVVideoCodecKey: AVVideoCodecH264,
                          AVVideoWidthKey: @(480),
                          AVVideoHeightKey: @(640),
                          AVVideoScalingModeKey: AVVideoScalingModeResizeAspect,
                          AVVideoCompressionPropertiesKey: compressionProperties,
                          };
    }
    return self;
}

- (void)dealloc {
    NSLog(@"=============XDCaptureService dealloc=============");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)startRunning {
    dispatch_async(_sessionQueue, ^{
        NSError *error = nil;
        BOOL result =  [self _setupSession:&error];
        if (result) {
            _isRunning = YES;
            [_captureSession startRunning];
        }else{
            if (self.delegate && [self.delegate respondsToSelector:@selector(captureService:serviceDidFailWithError:)]) {
                [self.delegate captureService:self serviceDidFailWithError:error];
            }
        }
    });
}

- (void)stopRunning {
    dispatch_async(_sessionQueue, ^{
        _isRunning = NO;
        NSError *error = nil;
        [self _clearVideoFile:&error];
        if (error) {
            if (self.delegate && [self.delegate respondsToSelector:@selector(captureService:serviceDidFailWithError:)]) {
                [self.delegate captureService:self serviceDidFailWithError:error];
            }
        }
        [_captureSession stopRunning];
    });
}

- (void)switchCamera {
    if (_openDepth) {
        return;
    }
    
    NSError *error;
    AVCaptureDevice *videoDevice = [self _inactiveCamera];
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
    
    if (videoInput) {
        [_captureSession beginConfiguration];
        
        [_captureSession removeInput:self.videoInput];
        
        if ([self.captureSession canAddInput:videoInput]) {
            [self.captureSession addInput:videoInput];
            self.videoInput = videoInput;
            //切换摄像头videoConnection会变化，所以需要重新获取
            self.videoConnection = [self.videoOutput connectionWithMediaType:AVMediaTypeVideo];
            if (_videoConnection.isVideoOrientationSupported) {
                _videoConnection.videoOrientation = AVCaptureVideoOrientationPortrait;
            }
        } else {
            [self.captureSession addInput:self.videoInput];
        }
        
        [self.captureSession commitConfiguration];
    }
    
    _devicePosition = _devicePosition == AVCaptureDevicePositionFront?AVCaptureDevicePositionBack:AVCaptureDevicePositionFront;
}

- (AVCaptureDevice *)_inactiveCamera {
    AVCaptureDevice *device = nil;
    if (_devicePosition == AVCaptureDevicePositionBack) {
        device = [self _cameraWithPosition:AVCaptureDevicePositionFront];
    } else {
        device = [self _cameraWithPosition:AVCaptureDevicePositionBack];
    }
    return device;
}

- (BOOL)depthSupported {
    NSString *deviceInfo = [self _getDeviceInfo];
    double sysVersion = [[self _getSystemVersion] doubleValue];
    NSArray *supportDuaDevices = @[@"iPhone9,2",@"iPhone10,2",@"iPhone10,5",];
    NSArray *supportXDevices = @[@"iPhone10,3",@"iPhone10,6"];
    BOOL deviceSupported = NO;
    if ([supportDuaDevices containsObject:deviceInfo] && _devicePosition == AVCaptureDevicePositionBack) {
        deviceSupported = YES;
    }
    if ([supportXDevices containsObject:deviceInfo]) {
        deviceSupported = YES;
    }
    BOOL systemSupported = sysVersion >= 11.0? YES:NO;
    return deviceSupported && systemSupported;
}

- (void)startRecording {
    dispatch_async(_writtingQueue, ^{
        NSString *videoFilePath = [_videoDir stringByAppendingPathComponent:[NSString stringWithFormat:@"Record-%llu.mp4",mach_absolute_time()]];
            
        _recordURL = [[NSURL alloc] initFileURLWithPath:videoFilePath];
            
        if (_recordURL) {
            _videoWriter = [[XDVideoWritter alloc] initWithURL:_recordURL VideoSettings:_videoSetting audioSetting:_audioSetting];
            _videoWriter.delegate = self;
            [_videoWriter startWriting];
            if (self.delegate && [self.delegate respondsToSelector:@selector(captureServiceRecorderDidStart:)]) {
                [self.delegate captureServiceRecorderDidStart:self];
            }
        } else {
            NSLog(@"No record URL");
        }
    });
}

- (void)cancleRecording {
    dispatch_async(_writtingQueue, ^{
        if (_videoWriter) {
            [_videoWriter cancleWriting];
        }
    });
}

- (void)stopRecording {
    dispatch_async(_writtingQueue, ^{
        if (_videoWriter) {
            [_videoWriter stopWritingAsyn];
        }
    });
}

- (void)capturePhoto {
    AVCaptureConnection *connection = [_imageOutput connectionWithMediaType:AVMediaTypeVideo];
    if (connection.isVideoOrientationSupported) {
        connection.videoOrientation = AVCaptureVideoOrientationPortrait;
    }
    
    __weak typeof(self) weakSelf = self;
    [_imageOutput captureStillImageAsynchronouslyFromConnection:connection completionHandler:^(CMSampleBufferRef  _Nullable imageDataSampleBuffer, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (imageDataSampleBuffer != NULL) {
            NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
            UIImage *image = [UIImage imageWithData:imageData];
            if (strongSelf.delegate && [strongSelf.delegate respondsToSelector:@selector(captureService:capturePhoto:)]) {
                [strongSelf.delegate captureService:strongSelf capturePhoto:image];
            }
        }
    }];
}

#pragma mark - session configuration
- (BOOL)_setupSession:(NSError **) error {
    if (_captureSession) {
        NSLog(@"session has existed");
        return YES;
    }
    
    if (![self _clearVideoFile:error]) {
        return NO;
    }
    
    if (![[NSFileManager defaultManager] createDirectoryAtPath:_videoDir withIntermediateDirectories:YES attributes:nil error:error]) {
        return NO;
    }
    
    _captureSession = [[AVCaptureSession alloc] init];
    _captureSession.sessionPreset = _sessionPreset;
    
    if (![self _setupVideoInputOutput:error]) {
        return NO;
    }
    
    if (![self _setupImageOutput:error]) {
        return NO;
    }
    
    if (self.shouldRecordAudio) {
        if (![self _setupAudioInputOutput:error]) {
            return NO;
        }
    }
    
    if (_openNativeFaceDetect) {
        if (![self _setupFaceDataOutput:error]) {
            return NO;
        }
    }
    
    if (self.preViewSource && [self.preViewSource respondsToSelector:@selector(preViewLayerSource)]) {
        self.previewLayer = [self.preViewSource preViewLayerSource];
        [_previewLayer setSession:_captureSession];
        [_previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    } else {
        self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
        //充满整个屏幕
        [_previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(captureService:getPreviewLayer:)]) {
            [self.delegate captureService:self getPreviewLayer:_previewLayer];
        }
    }
    
    //CaptureService和VideoWritter各自维护自己的生命周期，捕获视频流的状态与写入视频流的状态解耦分离，音视频状态变迁由captureservice内部管理，外层业务无需手动处理视频流变化
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_captureSessionNotification:) name:nil object:self.captureSession];
    
    //为了适配低于iOS 9的版本，在iOS 9以前，当session start 还没完成就退到后台，回到前台会捕获AVCaptureSessionRuntimeErrorNotification，这时需要手动重新启动session，iOS 9以后系统对此做了优化，系统退到后台后会将session start缓存起来，回到前台会自动调用缓存的session start，无需手动调用
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_enterForegroundNotification:) name:UIApplicationWillEnterForegroundNotification object:nil];
    
    return YES;
}

- (BOOL)_setupVideoInputOutput:(NSError **) error {
    self.currentDevice = [self _cameraWithPosition:_devicePosition];
    
    self.videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:_currentDevice error:error];
    if (_videoInput) {
        if ([_captureSession canAddInput:_videoInput]) {
            [_captureSession addInput:_videoInput];
        } else {
            *error = [NSError errorWithDomain:@"com.caixindong.captureservice.video" code:-2200 userInfo:@{NSLocalizedDescriptionKey:@"add video input fail"}];
            return NO;
        }
    } else {
        *error = [NSError errorWithDomain:@"com.caixindong.captureservice.video" code:-2201 userInfo:@{NSLocalizedDescriptionKey:@"video input is nil"}];
        return NO;
    }
    
    //稳定帧率
    CMTime frameDuration = CMTimeMake(1, _frameRate);
    if ([_currentDevice lockForConfiguration:error]) {
        _currentDevice.activeVideoMaxFrameDuration = frameDuration;
        _currentDevice.activeVideoMinFrameDuration = frameDuration;
        [_currentDevice unlockForConfiguration];
    } else {
        *error = [NSError errorWithDomain:@"com.caixindong.captureservice.video" code:-2203 userInfo:@{NSLocalizedDescriptionKey:@"device lock fail(input)"}];
        
        return NO;
    }
    
    self.videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    _videoOutput.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
    //对迟到的帧做丢帧处理
    _videoOutput.alwaysDiscardsLateVideoFrames = NO;
    
    dispatch_queue_t videoQueue = dispatch_queue_create("com.caixindong.captureservice.video", DISPATCH_QUEUE_SERIAL);
    [_videoOutput setSampleBufferDelegate:self queue:videoQueue];
    
    if ([_captureSession canAddOutput:_videoOutput]) {
        [_captureSession addOutput:_videoOutput];
    } else {
        *error = [NSError errorWithDomain:@"com.caixindong.captureservice.video" code:-2204 userInfo:@{NSLocalizedDescriptionKey:@"device lock fail(output)"}];
        return NO;
    }
    
    self.videoConnection = [self.videoOutput connectionWithMediaType:AVMediaTypeVideo];
    //录制视频会有90度偏转，是因为相机传感器问题，所以在这里设置输出的视频流的方向
    if (_videoConnection.isVideoOrientationSupported) {
        _videoConnection.videoOrientation = AVCaptureVideoOrientationPortrait;
    }
    return YES;
}

- (AVCaptureDevice *)_cameraWithPosition:(AVCaptureDevicePosition)position {
    if (@available(iOS 10.0, *)) {
        //AVCaptureDeviceTypeBuiltInWideAngleCamera默认广角摄像头，AVCaptureDeviceTypeBuiltInTelephotoCamera长焦摄像头，AVCaptureDeviceTypeBuiltInDualCamera后置双摄像头，AVCaptureDeviceTypeBuiltInTrueDepthCamera红外前置摄像头
        NSMutableArray *mulArr = [NSMutableArray arrayWithObjects:AVCaptureDeviceTypeBuiltInWideAngleCamera,AVCaptureDeviceTypeBuiltInTelephotoCamera,nil];
        if (@available(iOS 10.2, *)) {
            [mulArr addObject:AVCaptureDeviceTypeBuiltInDualCamera];
        }
        if (@available(iOS 11.1, *)) {
            [mulArr addObject:AVCaptureDeviceTypeBuiltInTrueDepthCamera];
        }
        AVCaptureDeviceDiscoverySession *discoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:[mulArr copy] mediaType:AVMediaTypeVideo position:position];
        return discoverySession.devices.firstObject;
    } else {
        NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        for (AVCaptureDevice *device in videoDevices) {
            if (device.position == position) {
                return device;
            }
        }
    }
    return nil;
}

- (BOOL)_setupImageOutput:(NSError **)error {
    self.imageOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary *outputSetting = @{AVVideoCodecKey: AVVideoCodecJPEG};
    [_imageOutput setOutputSettings:outputSetting];
    if ([_captureSession canAddOutput:_imageOutput]) {
        [_captureSession addOutput:_imageOutput];
        return YES;
    } else {
        *error = [NSError errorWithDomain:@"com.caixindong.captureservice.image" code:-2205 userInfo:@{NSLocalizedDescriptionKey:@"device lock fail(output)"}];
        return NO;
    }
}

- (BOOL)_setupAudioInputOutput:(NSError **)error {
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    
    self.audioInput = [[AVCaptureDeviceInput alloc] initWithDevice:audioDevice error:error];
    if (_audioInput) {
        if ([_captureSession canAddInput:_audioInput]) {
            [_captureSession addInput:_audioInput];
        } else {
            *error = [NSError errorWithDomain:@"com.caixindong.captureservice.audio" code:-2206 userInfo:@{NSLocalizedDescriptionKey:@"add audio input fail"}];
            return NO;
        }
    } else {
        *error = [NSError errorWithDomain:@"com.caixindong.captureservice.audio" code:-2207 userInfo:@{NSLocalizedDescriptionKey:@"device input is nil"}];
        return NO;
    }
    
    self.audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    dispatch_queue_t audioQueue = dispatch_queue_create("com.caixindong.captureservice.audio", DISPATCH_QUEUE_SERIAL);
    [_audioOutput setSampleBufferDelegate:self queue:audioQueue];
    
    if ([_captureSession canAddOutput:_audioOutput]) {
        [_captureSession addOutput:_audioOutput];
    } else {
        *error = [NSError errorWithDomain:@"com.caixindong.captureservice.audio" code:-2208 userInfo:@{NSLocalizedDescriptionKey:@"add audio output fail"}];
        return NO;
    }
    
    self.audioConnection = [self.audioOutput connectionWithMediaType:AVMediaTypeAudio];
    
    self.audioSetting = [[self.audioOutput recommendedAudioSettingsForAssetWriterWithOutputFileType:AVFileTypeMPEG4] copy];
    
    return YES;
}

- (BOOL)_setupFaceDataOutput:(NSError **)error {
    self.metadataOutput = [[AVCaptureMetadataOutput alloc] init];
    
    if ([_captureSession canAddOutput:_metadataOutput]) {
        [_captureSession addOutput:_metadataOutput];
        
        NSArray *metadataObjectTypes = @[AVMetadataObjectTypeFace];
        _metadataOutput.metadataObjectTypes = metadataObjectTypes;
        dispatch_queue_t metaQueue = dispatch_queue_create("com.caixindong.captureservice.meta", DISPATCH_QUEUE_SERIAL);
        [_metadataOutput setMetadataObjectsDelegate:self queue:metaQueue];
        return YES;
    } else {
        *error = [NSError errorWithDomain:@"com.caixindong.captureservice.face" code:-2209 userInfo:@{NSLocalizedDescriptionKey:@"add face output fail"}];
        
        return NO;
    }
}

- (BOOL)_clearVideoFile:(NSError **)error {
    NSString *tmpDirPath = NSTemporaryDirectory();
    NSString *videoDirPath = [tmpDirPath stringByAppendingPathComponent:XDCVIDEODIR];
    BOOL isDir = NO;
    BOOL existed = [[NSFileManager defaultManager] fileExistsAtPath:videoDirPath isDirectory:&isDir];
    if (isDir && existed) {
        if (![[NSFileManager defaultManager] removeItemAtPath:videoDirPath error:error]) {
            return NO;
        }
    }
    return YES;
}

#pragma mark - CaptureSession Notification
- (void)_captureSessionNotification:(NSNotification *)notification {
    NSLog(@"_captureSessionNotification:%@",notification.name);
    if ([notification.name isEqualToString:AVCaptureSessionDidStartRunningNotification]) {
        if (!_firstStartRunning) {
            NSLog(@"session start running");
            _firstStartRunning = YES;
            if (self.delegate && [self.delegate respondsToSelector:@selector(captureServiceDidStartService:)]) {
                [self.delegate captureServiceDidStartService:self];
            }
        } else {
            NSLog(@"session resunme running");
        }
    } else if ([notification.name isEqualToString:AVCaptureSessionDidStopRunningNotification]) {
        if (!_isRunning) {
            NSLog(@"session stop running");
            if (self.delegate && [self.delegate respondsToSelector:@selector(captureServiceDidStopService:)]) {
                [self.delegate captureServiceDidStopService:self];
            }
        } else {
            NSLog(@"interupte session stop running");
        }
    } else if ([notification.name isEqualToString:AVCaptureSessionWasInterruptedNotification]) {
        NSLog(@"session was interupted, userInfo: %@",notification.userInfo);
    } else if ([notification.name isEqualToString:AVCaptureSessionInterruptionEndedNotification]) {
        NSLog(@"session interupted end");
    } else if ([notification.name isEqualToString:AVCaptureSessionRuntimeErrorNotification]) {
        NSError *error = notification.userInfo[AVCaptureSessionErrorKey];
        if (error.code == AVErrorDeviceIsNotAvailableInBackground) {
            NSLog(@"session runtime error : AVErrorDeviceIsNotAvailableInBackground");
            _startSessionOnEnteringForeground = YES;
        } else {
            if (self.delegate && [self.delegate respondsToSelector:@selector(captureService:serviceDidFailWithError:)]) {
                [self.delegate captureService:self serviceDidFailWithError:error];
            }
        }
    } else {
        NSLog(@"handel other notification : %@",notification.name);
    }
}

#pragma mark - UIApplicationWillEnterForegroundNotification
- (void)_enterForegroundNotification:(NSNotification *)notification {
    if (_startSessionOnEnteringForeground == YES) {
        NSLog(@"为了适配低于iOS 9的版本，在iOS 9以前，当session start 还没完成就退到后台，回到前台会捕获AVCaptureSessionRuntimeErrorNotification，这时需要手动重新启动session，iOS 9以后系统对此做了优化，系统退到后台后会将session start缓存起来，回到前台会自动调用缓存的session start，无需手动调用");
        _startSessionOnEnteringForeground = NO;
        [self startRunning];
    }
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate && AVCaptureAudioDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    //可以捕获到不同的线程
    if (connection == _videoConnection) {
        [self _processVideoData:sampleBuffer];
    } else if (connection == _audioConnection) {
        [self _processAudioData:sampleBuffer];
    }
}

#pragma mark - XDVideoWritterDelegate
- (void)videoWritter:(XDVideoWritter *)writter didFailWithError:(NSError *)error {
    if (self.delegate && [self.delegate respondsToSelector:@selector(captureService:recorderDidFailWithError:)]) {
        [self.delegate captureService:self recorderDidFailWithError:error];
    }
}

- (void)videoWritter:(XDVideoWritter *)writter completeWriting:(NSError *)error {
    if (error) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(captureService:recorderDidFailWithError:)]) {
            [self.delegate captureService:self recorderDidFailWithError:error];
        }
    } else {
        if (self.delegate && [self.delegate respondsToSelector:@selector(captureServiceRecorderDidStop:)]) {
            [self.delegate captureServiceRecorderDidStop:self];
        }
    }
}

#pragma mark - AVCaptureMetadataOutputObjectsDelegate
-(void)captureOutput:(AVCaptureOutput *)output didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    NSMutableArray *transformedFaces = [NSMutableArray array];
    for (AVMetadataObject *face in metadataObjects) {
        @autoreleasepool{
            AVMetadataFaceObject *transformedFace = (AVMetadataFaceObject*)[self.previewLayer transformedMetadataObjectForMetadataObject:face];
            if (transformedFace) {
                [transformedFaces addObject:transformedFace];
            }
        };
    }
    @autoreleasepool{
        if (self.delegate && [self.delegate respondsToSelector:@selector(captureService:outputFaceDetectData:)]) {
            [self.delegate captureService:self outputFaceDetectData:[transformedFaces copy]];
        }
    };
}


#pragma mark - process Data
- (void)_processVideoData:(CMSampleBufferRef)sampleBuffer {
    //CFRetain的目的是为了每条业务线（写视频、抛帧）的sampleBuffer都是独立的
    if (_videoWriter && _videoWriter.isWriting) {
        CFRetain(sampleBuffer);
        dispatch_async(_writtingQueue, ^{
            [_videoWriter appendSampleBuffer:sampleBuffer];
            CFRelease(sampleBuffer);
        });
    }
    
    CFRetain(sampleBuffer);
    //及时清理临时变量，防止出现内存高峰
    dispatch_async(_outputQueue, ^{
        @autoreleasepool{
            if (self.delegate && [self.delegate respondsToSelector:@selector(captureService:outputSampleBuffer:)]) {
                [self.delegate captureService:self outputSampleBuffer:sampleBuffer];
            }
        }
        CFRelease(sampleBuffer);
    });
}

- (void)_processAudioData:(CMSampleBufferRef)sampleBuffer {
    if (_videoWriter && _videoWriter.isWriting) {
        CFRetain(sampleBuffer);
        dispatch_async(_writtingQueue, ^{
            [_videoWriter appendSampleBuffer:sampleBuffer];
            CFRelease(sampleBuffer);
        });
    }
}

- (void)_processDepthData:(AVDepthData *)depthData time:(CMTime)timestamp API_AVAILABLE(ios(11.0)){
    //像RGB图像一样，除了是单通道，但它们仍然可以表示为CV像素缓冲区，现在 CoreVideo 定义了在上一张幻灯片中看到类型的四个新像素格式。因为如果是在GPU上，会要求16位的值，而在CPU上，就都是32位的值
    AVDepthData *cDepthData = [depthData depthDataByConvertingToDepthDataType:kCVPixelFormatType_DepthFloat32];
    dispatch_async(_outputQueue, ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(captureService:captureTrueDepth:)]) {
            [self.delegate captureService:self captureTrueDepth:cDepthData];
        }
    });
    
}

#pragma mark - private
- (NSString *)_getDeviceInfo {
    int mib[2];
    size_t len;
    char *machine;
    
    mib[0] = CTL_HW;
    mib[1] = HW_MACHINE;
    sysctl(mib, 2, NULL, &len, NULL, 0);
    machine = malloc(len);
    sysctl(mib, 2, machine, &len, NULL, 0);
    
    NSString *platform = [NSString stringWithCString:machine encoding:NSASCIIStringEncoding];
    free(machine);
    
    return platform;
}

- (NSString *)_getSystemVersion {
    return [UIDevice currentDevice].systemVersion;
}

#pragma mark - camera setting
- (CGFloat)deviceISO {
    return _currentDevice.ISO;
}

- (CGFloat)deviceMinISO {
    return _currentDevice.activeFormat.minISO;
}

- (CGFloat)deviceMaxISO {
    return _currentDevice.activeFormat.maxISO;
}

- (CGFloat)deviceAperture {
    return _currentDevice.lensAperture;
}

- (AVCaptureExposureMode)exposureMode {
    return _currentDevice.exposureMode;
}

- (void)setExposureMode:(AVCaptureExposureMode)exposureMode {
    NSError *error = nil;
    if ([_currentDevice lockForConfiguration:&error]) {
        if (_currentDevice.isExposurePointOfInterestSupported && [_currentDevice isExposureModeSupported:exposureMode]) {
            _currentDevice.exposureMode = exposureMode;
        } else {
            NSLog(@"Device no support exposureMode");
        }
        [_currentDevice unlockForConfiguration];
    } else {
        NSLog(@"Device lock configuration error:%@",error.localizedDescription);
    }
}

- (void)setExposurePoint:(CGPoint)exposurePoint {
    NSError *error = nil;
    if ([_currentDevice lockForConfiguration:&error]) {
        if (_currentDevice.isExposurePointOfInterestSupported && [_currentDevice isExposureModeSupported:AVCaptureExposureModeAutoExpose]) {
            _currentDevice.exposureMode = AVCaptureExposureModeAutoExpose;
            _currentDevice.exposurePointOfInterest = exposurePoint;
        } else {
            NSLog(@"Device no support ExposurePointOfInterestSupported");
        }
        [_currentDevice unlockForConfiguration];
    } else {
        NSLog(@"Device lock configuration error:%@",error.localizedDescription);
    }
}

- (CMTime)deviceExposureDuration {
    return _currentDevice.exposureDuration;
}

- (AVCaptureFocusMode)focusMode {
    return _currentDevice.focusMode;
}

- (AVCaptureWhiteBalanceMode)whiteBalanceMode {
    return _currentDevice.whiteBalanceMode;
}

- (void)setWhiteBalanceMode:(AVCaptureWhiteBalanceMode)whiteBalanceMode {
    NSError *error = nil;
    if ([_currentDevice lockForConfiguration:&error]) {
        if ([_currentDevice isWhiteBalanceModeSupported:whiteBalanceMode]) {
            _currentDevice.whiteBalanceMode = whiteBalanceMode;
        } else {
            NSLog(@"Device no support whiteBalanceMode");
        }
    } else {
        NSLog(@"Device lock configuration error:%@",error.localizedDescription);
    }
}

- (void)setFocusMode:(AVCaptureFocusMode)focusMode {
    NSError *error = nil;
    if ([_currentDevice lockForConfiguration:&error]) {
        if (_currentDevice.isFocusPointOfInterestSupported && [_currentDevice isFocusModeSupported:focusMode]) {
            _currentDevice.focusMode = focusMode;
        } else {
            NSLog(@"Device no support focusMode");
        }
        [_currentDevice unlockForConfiguration];
    } else {
        NSLog(@"Device lock configuration error:%@",error.localizedDescription);
    }
}

- (void)setFocusPoint:(CGPoint)focusPoint {
    NSError *error = nil;
    if ([_currentDevice lockForConfiguration:&error]) {
        if (_currentDevice.isFocusPointOfInterestSupported && [_currentDevice isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
            _currentDevice.focusMode = AVCaptureFocusModeAutoFocus;
            _currentDevice.focusPointOfInterest = focusPoint;
        } else {
            NSLog(@"Device no support FocusPointOfInterestSupported");
        }
        [_currentDevice unlockForConfiguration];
    } else {
        NSLog(@"Device lock configuration error:%@",error.localizedDescription);
    }
}

- (BOOL)supportsTapToFocus {
    return [_currentDevice isFocusPointOfInterestSupported];
}

- (BOOL)supportsTapToExpose {
    return [_currentDevice isExposurePointOfInterestSupported];
}

- (BOOL)hasTorch {
    return _currentDevice.hasTorch;
}

- (AVCaptureTorchMode)torchMode {
    return _currentDevice.torchMode;
}

- (void)setTorchMode:(AVCaptureTorchMode)torchMode {
    if (_currentDevice.torchMode != torchMode && [_currentDevice isTorchModeSupported:torchMode]) {
        NSError *error;
        if ([_currentDevice lockForConfiguration:&error]) {
            _currentDevice.torchMode = torchMode;
            [_currentDevice unlockForConfiguration];
        } else {
            NSLog(@"Device lock configuration error:%@",error.localizedDescription);
        }
    } else {
        NSLog(@"Device no support torch");
    }
}

- (BOOL)hasFlash {
    return _currentDevice.hasFlash;
}

- (AVCaptureFlashMode)flashMode {
    return _currentDevice.flashMode;
}

- (void)setFlashMode:(AVCaptureFlashMode)flashMode {
    if (_currentDevice.flashMode != flashMode && [_currentDevice isFlashModeSupported:flashMode]) {
        NSError *error;
        if ([_currentDevice lockForConfiguration:&error]) {
            _currentDevice.flashMode = flashMode;
            [_currentDevice unlockForConfiguration];
        } else {
            NSLog(@"Device lock configuration error:%@",error.localizedDescription);
        }
    } else {
        NSLog(@"Device no support flash");
    }
}

@end
