//
//  XDCaptureService.h
//  XDCaptureService
//
//  Created by 蔡欣东 on 2018/2/26.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class XDCaptureService;


@protocol XDCaptureServiceDelegate <NSObject>

@optional
//service生命周期
- (void)captureServiceDidStartService:(XDCaptureService *)service;

- (void)captureService:(XDCaptureService *)service serviceDidFailWithError:(NSError *)error;

- (void)captureServiceDidStopService:(XDCaptureService *)service;

- (void)captureService:(XDCaptureService *)service getPreviewLayer:(AVCaptureVideoPreviewLayer *)previewLayer;

- (void)captureService:(XDCaptureService *)service outputSampleBuffer:(CMSampleBufferRef)sampleBuffer;

//录像相关
- (void)captureServiceRecorderDidStart:(XDCaptureService *)service ;

- (void)captureService:(XDCaptureService *)service recorderDidFailWithError:(NSError *)error;

- (void)captureServiceRecorderDidCancel:(XDCaptureService *)service;

- (void)captureServiceRecorderDidStop:(XDCaptureService *)service;

//照片捕获
- (void)captureService:(XDCaptureService *)service capturePhoto:(UIImage *)photo;

//人脸检测
- (void)captureService:(XDCaptureService *)service outputFaceDetectData:(NSArray <AVMetadataFaceObject*>*) faces;

//景深数据
- (void)captureService:(XDCaptureService *)service captureTrueDepth:(AVDepthData *)depthData API_AVAILABLE(ios(11.0));

@end

@protocol XDCaptureServicePreViewSource <NSObject>

- (AVCaptureVideoPreviewLayer *)preViewLayerSource;

@end

@interface XDCaptureService : NSObject

//是否录制音频，默认是NO
@property (nonatomic, assign) BOOL shouldRecordAudio;

//iOS原生人脸检测，默认是NO
@property (nonatomic, assign) BOOL openNativeFaceDetect;

//摄像头的方向，默认是AVCaptureDevicePositionFront（前置）
@property (nonatomic, assign) AVCaptureDevicePosition devicePosition;

//判断是否支持景深模式，当前只支持7p、8p、X的后置摄像头及X的前后摄像头,系统要求是iOS 11以上
@property (nonatomic, assign, readonly) BOOL depthSupported;

//是否开启景深模式，默认是NO
@property (nonatomic, assign) BOOL openDepth;

//只有以下指定的sessionPreset才有depth数据：AVCaptureSessionPresetPhoto、AVCaptureSessionPreset1280x720、AVCaptureSessionPreset640x480
@property (nonatomic, assign) AVCaptureSessionPreset sessionPreset;

//帧率，默认是30
@property (nonatomic, assign) int frameRate;

//录像的临时存储地址，建议每次录完视频做下重定向
@property (nonatomic, strong, readonly) NSURL *recordURL;

//如果设置preViewSource则内部不生成AVCaptureVideoPreviewLayer
@property (nonatomic, assign) id<XDCaptureServicePreViewSource> preViewSource;

@property (nonatomic, assign) id<XDCaptureServiceDelegate> delegate;

@property (nonatomic, assign, readonly) BOOL isRunning;

@property (nonatomic, assign, readonly) BOOL isRecording;


/**
 视频编码设置（影响录制的视频的编码和大小），默认是以下设置
 NSDictionary *compressionProperties = @{
 AVVideoAverageBitRateKey : @(640 * 480 * 2.1),
 AVVideoExpectedSourceFrameRateKey : @(30),
 AVVideoMaxKeyFrameIntervalKey : @(30),
 AVVideoProfileLevelKey:AVVideoProfileLevelH264Main41,
 };
 
 videoSetting = @{
 AVVideoCodecKey: AVVideoCodecH264,
 AVVideoWidthKey: @(480),
 AVVideoHeightKey: @(640),
 AVVideoScalingModeKey: AVVideoScalingModeResizeAspect,
 AVVideoCompressionPropertiesKey: compressionProperties,
 };
 **/
@property (nonatomic, strong) NSDictionary *videoSetting;

///相机专业设置，除非特定需求，一般不设置
//感光度（iOS8以上）
@property (nonatomic, assign, readonly) CGFloat deviceISO;
@property (nonatomic, assign, readonly) CGFloat deviceMinISO;
@property (nonatomic, assign, readonly) CGFloat deviceMaxISO;

//镜头光圈大小
@property (nonatomic, assign, readonly) CGFloat deviceAperture;

//曝光
@property (nonatomic, assign, readonly) BOOL supportsTapToExpose;
@property (nonatomic, assign) AVCaptureExposureMode exposureMode;
@property (nonatomic, assign) CGPoint exposurePoint;
@property (nonatomic, assign, readonly) CMTime deviceExposureDuration;

//聚焦
@property (nonatomic, assign, readonly) BOOL supportsTapToFocus;
@property (nonatomic, assign) AVCaptureFocusMode focusMode;
@property (nonatomic, assign) CGPoint focusPoint;

//白平衡
@property (nonatomic, assign) AVCaptureWhiteBalanceMode whiteBalanceMode;

//手电筒
@property (nonatomic, assign, readonly) BOOL hasTorch;
@property (nonatomic, assign) AVCaptureTorchMode torchMode;

//闪光灯
@property (nonatomic, assign, readonly) BOOL hasFlash;
@property (nonatomic, assign) AVCaptureFlashMode flashMode;

//相机权限判断
+ (BOOL)videoGranted;

//麦克风权限判断
+ (BOOL)audioGranted;

//切换摄像机
- (void)switchCamera;

//启动
- (void)startRunning;

//关闭
- (void)stopRunning;

//开始录像
- (void)startRecording;

//取消录像
- (void)cancleRecording;

//停止录像
- (void)stopRecording;

//拍照
- (void)capturePhoto;

@end
