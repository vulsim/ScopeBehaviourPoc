//
//  SpeechSession.h
//  Speech2Text
//
//  Created by Igor Mikheiko on 28.02.18.
//  Copyright © 2018 *instinctools. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SpeechSession : NSObject

@property (nonatomic, assign, readonly) BOOL isFinal;
@property (nonatomic, strong, readonly) NSString *transcription;
@property (nonatomic, strong) void (^transcriptionChanged)(NSString *transcription, BOOL isFinal);

@end
