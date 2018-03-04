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
@property (nonatomic, strong) SFSpeechAudioBufferRecognitionRequest *recognitionRequest;

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
    [self cleanup];
    [self finalizeAudioSession];
}

- (void)initializeAudioSession {
    NSError *error = nil;
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    [audioSession setMode:AVAudioSessionModeDefault error:&error];
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
    
    __weak typeof(self) weakSelf = self;
    
    [self.audioEngine prepare];
    [self.audioEngine.inputNode installTapOnBus:0
                                     bufferSize:1024
                                         format:[self.audioEngine.inputNode inputFormatForBus:0]
                                          block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
                                              [weakSelf.session.recognitionRequest appendAudioPCMBuffer:buffer];
                                          }];
    
    self.isInitialized = YES;
}

- (void)finalizeAudioSession {
    [self.audioEngine.inputNode removeTapOnBus:0];
    self.isInitialized = NO;
}

- (void)pendingSessionWithTimeout:(NSTimeInterval)timeout
                       completion:(void (^)(NSError *error, SpeechSession *session))completion {
    
    if (!completion) {
        return;
    }
    
    if (!self.isInitialized) {
        completion([self errorWithCode:1003 message:@"Speech recognizer not initialized."], nil);
        return;
    }
    
    if (self.session) {
        completion([self errorWithCode:1003 message:@"Only one session can be started simultaneously."], nil);
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    __weak NSTimer *pendingTimer = nil;
    __block BOOL alreadyDone = NO;

    SFSpeechAudioBufferRecognitionRequest *recognitionRequest = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
    recognitionRequest.shouldReportPartialResults = YES;
    recognitionRequest.taskHint = SFSpeechRecognitionTaskHintDictation;
    
    SpeechSession *session = [[SpeechSession alloc] init];

    self.session = session;
    self.session.recognitionRequest = recognitionRequest;
    self.session.recognitionTask = [self.recognizer recognitionTaskWithRequest:recognitionRequest
                                                               resultHandler:^(SFSpeechRecognitionResult * _Nullable result, NSError * _Nullable error) {
                                                                   __strong typeof(self) strongSelf = weakSelf;
                                                                   [pendingTimer invalidate];
                                                                   
                                                                   if (result) {
                                                                       NSLog(@"%d, %@", result.isFinal, result.bestTranscription.formattedString);
                                                                       [session setTranscription:result.bestTranscription.formattedString
                                                                                         isFinal:result.isFinal];
                                                                   }
                                                                   
                                                                   if (!alreadyDone) {
                                                                       alreadyDone = YES;
                                                                       
                                                                       if (!error && !result) {
                                                                           completion([strongSelf errorWithCode:1004 message:@"Timeout expired."], nil);
                                                                       } else {
                                                                           completion(error, result ? session : nil);
                                                                       }
                                                                   }
                                                                   
                                                                   if (error || result.isFinal) {
                                                                       [strongSelf cleanup];
                                                                   }
                                                               }];
    
    NSError *error = nil;
    
    NSLog(@"Start");
    [self.audioEngine startAndReturnError:&error];
    
    if (error) {
        alreadyDone = YES;
        completion(error, nil);
        [self cleanup];
        return;
    }
    
    pendingTimer = [NSTimer scheduledTimerWithTimeInterval:timeout repeats:NO block:^(NSTimer * _Nonnull timer) {
        [weakSelf cleanup];
    }];
}

- (void)cleanup {
    if (!self.session) {
        return;
    }
    
    NSLog(@"Stop");
    [self.session.recognitionRequest endAudio];
    [self.audioEngine stop];
    
    self.session.recognitionRequest = nil;
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
