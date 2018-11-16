//
//  XDVideoWritter.h
//  XDCaptureService
//
//  Created by 蔡欣东 on 2018/2/26.
//

#import <AVFoundation/AVFoundation.h>

@class XDVideoWritter;

@protocol XDVideoWritterDelegate<NSObject>

@optional

- (void)videoWritter:(XDVideoWritter *)writter didFailWithError:(NSError *)error;

- (void)videoWritter:(XDVideoWritter *)writter completeWriting:(NSError *)error;

@end

@interface XDVideoWritter : NSObject

@property (nonatomic, readonly, assign) BOOL isWriting;

@property (nonatomic, assign) id<XDVideoWritterDelegate> delegate;

- (instancetype)initWithURL:(NSURL*)URL
              VideoSettings:(NSDictionary *)videoSetting
               audioSetting:(NSDictionary *)audioSetting;

- (void)startWriting;

- (void)cancleWriting;

- (void)stopWritingAsyn;

- (void)appendSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@end
