#import "HSSpeechBridgeModule.h"
#import "LocaleUtil.h"
#import <Photos/Photos.h>
#import <React/RCTConvert.h>

@implementation HSSpeechBridgeModule {
  bool hasListeners;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    HSSpeechManager.sharedInstance.delegate = self;
  }
  return self;
}

#pragma mark - SpeechManagerDelegate

- (void)speechManagerDidBecomeAvailable {
  if (!hasListeners) {
    return;
  }
  [self sendEventWithName:@"speechTranscriptionDidBecomeAvailable" body:@{}];
}

- (void)speechManagerDidBecomeUnavailable {
  if (!hasListeners) {
    return;
  }
  [self sendEventWithName:@"speechTranscriptionDidBecomeUnavailable" body:@{}];
}

- (void)speechManagerDidChangeLocale:(NSLocale *)locale {
  if (!hasListeners) {
    return;
  }
  NSDictionary *json = [LocaleUtil jsonify:locale];
  [self sendEventWithName:@"speechTranscriptionDidChangeLocale" body:json];
}

- (void)speechManagerDidReceiveSpeechTranscriptionWithIsFinal:(BOOL)isFinal
                                                transcription:
                                                    (HSSpeechTranscription *)
                                                        transcription {
  if (!hasListeners) {
    return;
  }
  NSString *string = transcription.string;
  NSMutableArray<NSDictionary *> *segments =
      [[NSMutableArray alloc] initWithCapacity:transcription.segments.count];
  for (HSSpeechTranscriptionSegment *segment in transcription.segments) {
    [segments addObject:@{
      @"duration" : @(segment.duration),
      @"timestamp" : @(segment.timestamp),
      @"confidence" : @(segment.confidence),
      @"substring" : segment.substring,
    }];
  }
  NSLocale *locale = HSSpeechManager.sharedInstance.locale;
  NSDictionary *body = @{
    @"isFinal" : @(isFinal),
    @"formattedString" : string,
    @"segments" : segments,
    @"locale" : [LocaleUtil jsonify:locale]
  };
  [self sendEventWithName:@"speechTranscriptionDidOutput" body:body];
}

- (void)speechManagerDidNotDetectSpeech {
  if (!hasListeners) {
    return;
  }
  [self sendEventWithName:@"speechTranscriptionDidNotDetectSpeech" body:@{}];
}

- (void)speechManagerDidEnd {
  if (!hasListeners) {
    return;
  }
  [self sendEventWithName:@"speechTranscriptionDidEnd" body:@{}];
}

- (void)speechManagerDidFail {
  if (!hasListeners) {
    return;
  }
  [self sendEventWithName:@"speechTranscriptionDidFail" body:@{}];
}

#pragma mark - React Native module

- (void)startObserving {
  hasListeners = YES;
}

- (void)stopObserving {
  hasListeners = NO;
}

+ (BOOL)requiresMainQueueSetup {
  return NO;
}

- (NSArray<NSString *> *)supportedEvents {
  return @[
    @"speechTranscriptionDidBecomeAvailable",
    @"speechTranscriptionDidBecomeUnavailable",
    @"speechTranscriptionDidChangeLocale",
    @"speechTranscriptionDidEnd",
    @"speechTranscriptionDidBegin",
    @"speechTranscriptionDidFail",
    @"speechTranscriptionDidNotDetectSpeech",
    @"speechTranscriptionDidOutput",
  ];
}

RCT_EXPORT_MODULE(HSSpeechManager)

RCT_EXPORT_METHOD(beginSpeechTranscriptionOfAsset
                  : (NSString *)assetID withCallback
                  : (RCTResponseSenderBlock)callback) {
  PHFetchResult<PHAsset *> *fetchResult =
      [PHAsset fetchAssetsWithLocalIdentifiers:@[ assetID ] options:nil];
  PHAsset *asset = fetchResult.firstObject;
  if (asset == nil) {
    callback(@[ [NSNull null], @(NO) ]);
    return;
  }
  PHVideoRequestOptions *requestOptions = [[PHVideoRequestOptions alloc] init];
  requestOptions.deliveryMode =
      PHVideoRequestOptionsDeliveryModeHighQualityFormat;
  [PHImageManager.defaultManager
      requestAVAssetForVideo:asset
                     options:requestOptions
               resultHandler:^(AVAsset *asset, AVAudioMix *audioMix,
                               NSDictionary *info) {
                 if (self->hasListeners) {
                   [self sendEventWithName:@"speechTranscriptionDidBegin"
                                      body:@{}];
                 }
                 [HSSpeechManager.sharedInstance
                     startCaptureForAsset:asset
                                 callback:^(NSError *error, BOOL success) {
                                   if (error != nil) {
                                     callback(@[ error, @(NO) ]);
                                     return;
                                   }
                                   callback(@[ [NSNull null], @(success) ]);
                                 }];
               }];
}

RCT_EXPORT_METHOD(beginSpeechTranscriptionOfAudioSession
                  : (RCTResponseSenderBlock)callback) {
  if (hasListeners) {
    [self sendEventWithName:@"speechTranscriptionDidBegin" body:@{}];
  }
  [HSSpeechManager.sharedInstance
      startCaptureForAudioSessionWithCallback:^(NSError *error, BOOL success) {
        if (error != nil) {
          callback(@[ error, @(NO) ]);
          return;
        }
        callback(@[ [NSNull null], @(success) ]);
      }];
}

RCT_EXPORT_METHOD(endSpeechTranscriptionOfAudioSession
                  : (RCTResponseSenderBlock)callback) {
  [HSSpeechManager.sharedInstance stopCaptureForAudioSession];
  callback(@[ [NSNull null], @(YES) ]);
}

RCT_EXPORT_METHOD(getCurrentLocale : (RCTResponseSenderBlock)callback) {
  NSLocale *locale = HSSpeechManager.sharedInstance.locale;
  NSDictionary *json = [LocaleUtil jsonify:locale];
  callback(@[ [NSNull null], json ]);
}

RCT_EXPORT_METHOD(getSupportedLocales : (RCTResponseSenderBlock)callback) {
  NSSet<NSLocale *> *locales =
      [HSSpeechManager.sharedInstance supportedLocales];
  NSMutableSet<NSDictionary *> *jsonifiedLocales =
      [[NSMutableSet alloc] initWithCapacity:locales.count];
  for (NSLocale *locale in locales) {
    NSString *languageCode = locale.languageCode;
    NSString *countryCode = locale.countryCode;
    if (!languageCode || !countryCode) {
      continue;
    }
    NSDictionary *json = [LocaleUtil jsonify:locale];
    [jsonifiedLocales addObject:json];
  }
  callback(@[ [NSNull null], [jsonifiedLocales allObjects] ]);
}

RCT_EXPORT_METHOD(setLocale
                  : (NSString *)identifier withCallback
                  : (RCTResponseSenderBlock)callback) {
  NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:identifier];
  if (!locale) {
    callback(@[ [NSNull null], @(NO) ]);
    return;
  }
  BOOL success = [HSSpeechManager.sharedInstance setLocale:locale];
  callback(@[ [NSNull null], @(success) ]);
}

RCT_EXPORT_METHOD(hasSpeechPermissions : (RCTResponseSenderBlock)callback) {
  BOOL isAuthorized = [HSSpeechManager.sharedInstance isAuthorized];
  callback(@[ [NSNull null], @(isAuthorized) ]);
}

RCT_EXPORT_METHOD(requestSpeechPermissions : (RCTResponseSenderBlock)callback) {
  [HSSpeechManager.sharedInstance authorize:^(BOOL isAuthorized) {
    callback(@[ [NSNull null], @(isAuthorized) ]);
  }];
}

@end
