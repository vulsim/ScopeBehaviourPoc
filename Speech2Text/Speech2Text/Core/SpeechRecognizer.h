//
//  SpeechRecognizer.h
//  Speech2Text
//
//  Created by Igor Mikheiko on 28.02.18.
//  Copyright © 2018 *instinctools. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SpeechSession.h"

@interface SpeechRecognizer : NSObject

@property (nonatomic, strong) void (^initializationError)(NSError *error);

- (instancetype)initWithLocale:(NSLocale *)locale;

- (void)pendingSessionWithTimeout:(NSTimeInterval)timeout
                       completion:(void (^)(NSError *error, SpeechSession *session))completion;

- (void)cleanup;

@end
