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
//service
- (void)captureServiceDidStartService:(XDCaptureService *)service;

- (void)captureService:(XDCaptureService *)service serviceDidFailWithError:(NSError *)error;

- (void)captureServiceDidStopService:(XDCaptureService *)service;

- (void)captureService:(XDCaptureService *)service getPreviewLayer:(AVCaptureVideoPreviewLayer *)previewLayer;

- (void)captureService:(XDCaptureService *)service outputPixelBuffer:(CVPixelBufferRef)pixelBuffer;

- (void)captureService:(XDCaptureService *)service outputAudioData:(NSData *)audioData;
//recorder
- (void)captureServiceRecorderDidStart:(XDCaptureService *)service ;

- (void)captureService:(XDCaptureService *)service recorderDidFailWithError:(NSError *)error;

- (void)captureServiceRecorderDidStop:(XDCaptureService *)service;
//face detect
- (void)captureService:(XDCaptureService *)service outputFaceDetectData:(NSArray <AVMetadataFaceObject*>*) faces;

@end

@interface XDCaptureService : NSObject

@property (nonatomic, assign) id<XDCaptureServiceDelegate> delegate;
//Default is YES
@property (nonatomic, assign) BOOL shouldRecordAudio;
//Default is NO
@property (nonatomic, assign) BOOL openNativeFaceDetect;

@property (nonatomic, strong, readonly) NSURL *recordURL;
//Default is AVCaptureDevicePositionFront
@property (nonatomic, assign) AVCaptureDevicePosition devicePosition;

@property (nonatomic, assign, readonly) BOOL isRunning;

+ (BOOL)videoGranted;

+ (BOOL)audioGranted;

- (void)startRunning;

- (void)stopRunning;

- (void)startRecording;

- (void)cancleRecording;

- (void)stopRecording;

@end
