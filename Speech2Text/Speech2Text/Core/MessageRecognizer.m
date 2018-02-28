//
//  MessageRecognizer.m
//  Speech2Text
//
//  Created by Igor Mikheiko on 28.02.18.
//  Copyright © 2018 *instinctools. All rights reserved.
//

#import "MessageRecognizer.h"
#import "SpeechRecognizer.h"

@interface MessageRecognizer()

@property (nonatomic, assign) BOOL isStarted;
@property (nonatomic, strong) SpeechRecognizer *recognizer;
@property (nonatomic, weak) NSTimer *barrierTimer;

@end

@implementation MessageRecognizer

- (instancetype)initWithLocale:(NSLocale *)locale {
    if (self = [super init]) {
        __weak typeof(self) weakSelf = self;
        
        self.recognizer = [[SpeechRecognizer alloc] initWithLocale:locale];
        self.recognizer.initializationError = ^(NSError *error) {
            if (weakSelf.onError) {
                weakSelf.onError(error);
            }
        };
    }
    return self;
}

- (void)start {
    self.isStarted = YES;
    [self schedule];
}

- (void)stop {
    self.isStarted = NO;
}

- (void)schedule {
    if (!self.isStarted) {
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    
    [NSTimer scheduledTimerWithTimeInterval:1.0f repeats:NO block:^(NSTimer * _Nonnull timer) {
        [weakSelf.recognizer pendingSessionWithTimeout:30.0f completion:^(NSError *error, SpeechSession *session) {
            __strong typeof(self) strongSelf = weakSelf;
            
            if (error) {
                [strongSelf schedule];
                return;
            }
            
            if (session) {
                if (strongSelf.beginMessage) {
                    strongSelf.beginMessage(session.transcription);
                }
                
                session.transcriptionChanged = ^(NSString *transcription, BOOL isFinal) {
                    __strong typeof(self) strongSelf = weakSelf;
                    [strongSelf.barrierTimer invalidate];
                    
                    if (isFinal) {
                        if (strongSelf.endMessage) {
                            strongSelf.endMessage(transcription);
                        }
                        
                        [strongSelf schedule];
                    } else {
                        if (strongSelf.continueMessage) {
                            strongSelf.continueMessage(transcription);
                        }
                        
                        strongSelf.barrierTimer = [NSTimer scheduledTimerWithTimeInterval:2.0f repeats:NO block:^(NSTimer * _Nonnull timer) {
                            __strong typeof(self) strongSelf = weakSelf;
                            
                            [strongSelf.recognizer clearSession];
                            
                            if (strongSelf.endMessage) {
                                strongSelf.endMessage(transcription);
                            }
                            
                            [strongSelf schedule];
                        }];
                    }
                };
            }
        }];
    }];
}

@end
