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
@property (nonatomic, weak) NSTimer *sessionTimer;

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
    
    [NSTimer scheduledTimerWithTimeInterval:0.5f repeats:NO block:^(NSTimer * _Nonnull timer) {
        [weakSelf.recognizer pendingSessionWithTimeout:3.0f completion:^(NSError *error, SpeechSession *session) {
            __strong typeof(self) strongSelf = weakSelf;
            
            if (error) {
                NSLog(@"%@", error);
            }
            
            if (session) {
                strongSelf.sessionTimer = [NSTimer scheduledTimerWithTimeInterval:30.0f repeats:NO block:^(NSTimer * _Nonnull timer) {
                    [strongSelf.barrierTimer invalidate];
                    [strongSelf.recognizer cleanup];
                }];
                
                strongSelf.barrierTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f repeats:NO block:^(NSTimer * _Nonnull timer) {
                    [strongSelf.sessionTimer invalidate];
                    [strongSelf.recognizer cleanup];
                }];
                
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
                            [strongSelf.sessionTimer invalidate];
                            [strongSelf.recognizer cleanup];                            
                        }];
                    }
                };
            } else {
                [strongSelf.recognizer cleanup];
                [strongSelf schedule];
            }
        }];
    }];
}

@end
