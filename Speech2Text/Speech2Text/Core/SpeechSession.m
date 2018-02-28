//
//  SpeechSession.m
//  Speech2Text
//
//  Created by Igor Mikheiko on 28.02.18.
//  Copyright © 2018 *instinctools. All rights reserved.
//

#import "SpeechSession.h"
#import <Speech/Speech.h>

@interface SpeechSession()

@property (nonatomic, assign) BOOL isFinal;
@property (nonatomic, strong) NSString *transcription;
@property (nonatomic, strong) SFSpeechRecognitionTask *recognitionTask;

@end

@implementation SpeechSession

- (void)setTranscription:(NSString *)transcription isFinal:(BOOL)isFinal {
    self.transcription = transcription;
    self.isFinal = isFinal;
    
    if (self.transcriptionChanged) {
        self.transcriptionChanged(transcription, isFinal);
    }
}

@end
