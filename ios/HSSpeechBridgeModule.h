#pragma once

#import "HSReactNativeSpeech-Swift.h"
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface HSSpeechBridgeModule
    : RCTEventEmitter <RCTBridgeModule, HSSpeechManagerDelegate>
- (void)speechManagerDidReceiveSpeechTranscriptionWithIsFinal:(BOOL)isFinal
                                                transcription:
                                                    (HSSpeechTranscription *)
                                                        transcription;
- (void)speechManagerDidBecomeAvailable;
- (void)speechManagerDidBecomeUnavailable;
- (void)speechManagerDidNotDetectSpeech;
- (void)speechManagerDidEnd;
- (void)speechManagerDidFail;
- (void)speechManagerDidChangeLocale:(NSLocale *)locale;
@end
