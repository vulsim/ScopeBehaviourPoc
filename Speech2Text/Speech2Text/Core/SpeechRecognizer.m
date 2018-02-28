//
//  SpeechRecognizer.m
//  Speech2Text
//
//  Created by Igor Mikheiko on 28.02.18.
//  Copyright © 2018 *instinctools. All rights reserved.
//

#import "SpeechRecognizer.h"
#import <Speech/Speech.h>

#pragma mark - SpeechSession

@interface SpeechSession (Private)

@property (nonatomic, strong) SFSpeechRecognitionTask *recognitionTask;

- (void)setTranscription:(NSString *)transcription isFinal:(BOOL)isFinal;

@end

#pragma mark - SpeechRecognizer

@interface SpeechRecognizer() <SFSpeechRecognizerDelegate>

@property (nonatomic, assign) BOOL isInitialized;
@property (nonatomic, strong) AVAudioEngine *audioEngine;
@property (nonatomic, strong) SFSpeechRecognizer *recognizer;
@property (nonatomic, strong) SpeechSession *session;

@end

@implementation SpeechRecognizer

- (instancetype)initWithLocale:(NSLocale *)locale {
    if (self = [super init]) {
        self.audioEngine = [[AVAudioEngine alloc] init];
        self.recognizer = [[SFSpeechRecognizer alloc] initWithLocale:locale];
        self.recognizer.delegate = self;

        __weak typeof(self) weakSelf = self;
        
        [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
            if (status == SFSpeechRecognizerAuthorizationStatusAuthorized) {
                [weakSelf initializeAudioSession];
            } else if (weakSelf.initializationError) {
                weakSelf.initializationError([self errorWithCode:1001 message:@"Speech recognizer not unauthorized."]);
            }
        }];
    }
    return self;
}

- (void)dealloc {
    [self clearSession];
}

- (void)initializeAudioSession {
    NSError *error = nil;
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryRecord error:&error];
    [audioSession setMode:AVAudioSessionModeMeasurement error:&error];
    [audioSession setActive:true withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&error];
    
    if (error) {
        if (self.initializationError) {
            self.initializationError(error);
        }
        return;
    }
    
    if (!self.audioEngine.inputNode) {
        if (self.initializationError) {
            self.initializationError([self errorWithCode:1002 message:@"Can't initialize audio session."]);
        }
        return;
    }
    
    self.isInitialized = YES;
}

- (void)pendingSessionWithTimeout:(NSTimeInterval)timeout
                       completion:(void (^)(NSError *error, SpeechSession *session))completion {
    
    __block void (^pendingResult)(NSError *error, SpeechSession *session) = completion;
    
    if (!pendingResult) {
        return;
    }
    
    if (!self.isInitialized) {
        pendingResult([self errorWithCode:1003 message:@"Speech recognizer not initialized."], nil);
        return;
    }
    
    if (self.session) {
        pendingResult([self errorWithCode:1003 message:@"Only one session can be started simultaneously."], nil);
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    
    SFSpeechAudioBufferRecognitionRequest *recognitionRequest = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
    recognitionRequest.shouldReportPartialResults = YES;
    
    [self.audioEngine.inputNode installTapOnBus:0
                                     bufferSize:1024
                                         format:[self.audioEngine.inputNode inputFormatForBus:0]
                                          block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
                                              [recognitionRequest appendAudioPCMBuffer:buffer];
                                          }];

    self.session = [[SpeechSession alloc] init];
    self.session.recognitionTask = [self.recognizer recognitionTaskWithRequest:recognitionRequest
                                                               resultHandler:^(SFSpeechRecognitionResult * _Nullable result, NSError * _Nullable error) {
                                                                   __strong typeof(self) strongSelf = weakSelf;
                                                                   
                                                                   if (result) {
                                                                       [strongSelf.session setTranscription:result.bestTranscription.formattedString
                                                                                                    isFinal:result.isFinal];
                                                                   }
                                                                   
                                                                   if (pendingResult) {
                                                                       pendingResult(error, error ? nil : strongSelf.session);
                                                                       pendingResult = nil;
                                                                   }
                                                                   
                                                                   if (error || result.isFinal) {
                                                                       [strongSelf clearSession];
                                                                   }
                                                               }];
    
    NSError *error = nil;
    [self.audioEngine startAndReturnError:&error];
    
    if (error) {
        if (pendingResult) {
            pendingResult(error, nil);
        }
        [self clearSession];
        return;
    }
    
    [NSTimer scheduledTimerWithTimeInterval:timeout repeats:NO block:^(NSTimer * _Nonnull timer) {
        __strong typeof(self) strongSelf = weakSelf;
        
        [strongSelf clearSession];
        
        if (pendingResult) {
            pendingResult([strongSelf errorWithCode:1004 message:@"Timeout expired."], nil);
            pendingResult = nil;
        }
    }];
}

- (void)clearSession {
    [self.audioEngine stop];
    [self.audioEngine.inputNode removeTapOnBus:0];
    [self.session.recognitionTask cancel];
    self.session.recognitionTask = nil;
    self.session = nil;
}

#pragma mark - SFSpeechRecognizerDelegate

- (void)speechRecognizer:(SFSpeechRecognizer *)speechRecognizer availabilityDidChange:(BOOL)available {
    
}

#pragma mark - Internal

- (NSError *)errorWithCode:(NSInteger)code message:(NSString *)message  {
    return [NSError errorWithDomain:NSStringFromClass([self class]) code:code userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(message, nil)}];
}

@end
