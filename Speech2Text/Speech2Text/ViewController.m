//
//  ViewController.m
//  Speech2Text
//
//  Created by Igor Mikheiko on 14.02.18.
//  Copyright © 2018 *instinctools. All rights reserved.
//

#import "ViewController.h"
#import <Speech/Speech.h>

@interface ViewController () <SFSpeechRecognizerDelegate>

@property (nonatomic, weak) IBOutlet UITextView *textView;
@property (nonatomic, strong) SFSpeechRecognizer *speechRecognizer;
@property (nonatomic, strong) SFSpeechRecognitionTask *recognitionTask;
@property (nonatomic, weak) SFSpeechAudioBufferRecognitionRequest *recognitionRequest;
@property (nonatomic, strong) AVAudioEngine *audioEngine;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:[NSLocale localeWithLocaleIdentifier:@"ru_RU"]];
    self.speechRecognizer.delegate = self;
    self.audioEngine = [[AVAudioEngine alloc] init];
    
    __weak typeof(self) weakSelf = self;
    
    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
        if (status == SFSpeechRecognizerAuthorizationStatusAuthorized) {
            [weakSelf initializeSpeechRecognizer];
            [weakSelf startRecording];
        }
    }];
}

- (void)initializeSpeechRecognizer {
    NSError *error = nil;

    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryRecord error:&error];
    [audioSession setMode:AVAudioSessionModeMeasurement error:&error];
    [audioSession setActive:true withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation  error:&error];
    
    if (error || !self.audioEngine.inputNode) {
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    
    [self.audioEngine.inputNode installTapOnBus:0
                                     bufferSize:1024
                                         format:[self.audioEngine.inputNode inputFormatForBus:0]
                                          block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
                                              [weakSelf.recognitionRequest appendAudioPCMBuffer:buffer];
                                          }];
}

- (void)startRecording {
    SFSpeechAudioBufferRecognitionRequest *recognitionRequest = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
    recognitionRequest.shouldReportPartialResults = YES;
    
    __weak typeof(self) weakSelf = self;
    
    self.recognitionRequest = recognitionRequest;
    self.recognitionTask = [self.speechRecognizer recognitionTaskWithRequest:recognitionRequest
                                                               resultHandler:^(SFSpeechRecognitionResult * _Nullable result, NSError * _Nullable error) {
                                                                   if (result) {
                                                                       weakSelf.textView.text = result.bestTranscription.formattedString;
                                                                   }
                                                                   
                                                                   if (error || result.isFinal) {
                                                                       [weakSelf stopRecording];
                                                                   }
                                                               }];
    [self.audioEngine startAndReturnError:nil];
}

- (void)stopRecording {
    [self.audioEngine stop];
    self.recognitionRequest = nil;
    self.recognitionTask = nil;
}

#pragma mark - SFSpeechRecognizerDelegate

- (void)speechRecognizer:(SFSpeechRecognizer *)speechRecognizer availabilityDidChange:(BOOL)available {
    
}

@end
