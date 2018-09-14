# XDCaptureService

[![CI Status](http://img.shields.io/travis/458770054@qq.com/XDCaptureService.svg?style=flat)](https://travis-ci.org/458770054@qq.com/XDCaptureService)
[![Version](https://img.shields.io/cocoapods/v/XDCaptureService.svg?style=flat)](http://cocoapods.org/pods/XDCaptureService)
[![License](https://img.shields.io/cocoapods/l/XDCaptureService.svg?style=flat)](http://cocoapods.org/pods/XDCaptureService)
[![Platform](https://img.shields.io/cocoapods/p/XDCaptureService.svg?style=flat)](http://cocoapods.org/pods/XDCaptureService)           
A simple and stable camera component in iOS, which can help quickly build your own audio and video module.
## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Installation

XDCaptureService is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'XDCaptureService'
```

## Usage
#### Start service
```
@property (nonatomic, strong) XDCaptureService *service;
self.service = [[XDCaptureService alloc] init];
_service.delegate = self;

[_service startRunning];
```
#### Delegate implement
```
@protocol XDCaptureServiceDelegate <NSObject>

@optional
//service lifecylce
- (void)captureServiceDidStartService:(XDCaptureService *)service;

- (void)captureService:(XDCaptureService *)service serviceDidFailWithError:(NSError *)error;

- (void)captureServiceDidStopService:(XDCaptureService *)service;

- (void)captureService:(XDCaptureService *)service getPreviewLayer:(AVCaptureVideoPreviewLayer *)previewLayer;

- (void)captureService:(XDCaptureService *)service outputSampleBuffer:(CMSampleBufferRef)sampleBuffer;

//record module
- (void)captureServiceRecorderDidStart:(XDCaptureService *)service ;

- (void)captureService:(XDCaptureService *)service recorderDidFailWithError:(NSError *)error;

- (void)captureServiceRecorderDidStop:(XDCaptureService *)service;

//photo capture
- (void)captureService:(XDCaptureService *)service capturePhoto:(UIImage *)photo;

//face detect
- (void)captureService:(XDCaptureService *)service outputFaceDetectData:(NSArray <AVMetadataFaceObject*>*) faces;

//depth map
- (void)captureService:(XDCaptureService *)service captureTrueDepth:(AVDepthData *)depthData API_AVAILABLE(ios(11.0));

@end
```

#### Base actions
Capture a photo, record a video, face detect, capture depth map data, switch camera, focus, whiteBalance，ISO and so on.

#### More details
You can view more usage details in the demo project.

## Author

458770054@qq.com

## License

XDCaptureService is available under the MIT license. See the LICENSE file for more info.
