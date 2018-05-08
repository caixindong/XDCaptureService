//
//  XDVideoWritter.m
//  XDCaptureService
//
//  Created by 蔡欣东 on 2018/2/26.
//

#import "XDVideoWritter.h"

@interface XDVideoWritter()

@property (nonatomic, strong) AVAssetWriter *assetWriter;

@property (nonatomic, strong) AVAssetWriterInput *videoInput;

@property (nonatomic, strong) AVAssetWriterInput *audioInput;

@property (nonatomic, strong) NSDictionary *videoSetting;

@property (nonatomic, strong) NSDictionary *audioSetting;

@property (nonatomic, strong) dispatch_queue_t dispatchQueue;

@property (nonatomic, strong) NSURL *outputURL;

@property (nonatomic, assign) BOOL isWriting;

@property (nonatomic, assign) BOOL firstSample;

@end

@implementation XDVideoWritter

- (instancetype)initWithURL:(NSURL *)URL VideoSettings:(NSDictionary *)videoSetting audioSetting:(NSDictionary *)audioSetting dispatchQueue:(dispatch_queue_t)dispatchQueue {
    if (self = [super init]) {
        
    }
    return self;
}

@end
