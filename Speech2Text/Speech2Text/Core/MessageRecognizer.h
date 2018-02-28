//
//  MessageRecognizer.h
//  Speech2Text
//
//  Created by Igor Mikheiko on 28.02.18.
//  Copyright © 2018 *instinctools. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MessageRecognizer : NSObject

@property (nonatomic, strong) void (^onError)(NSError *error);
@property (nonatomic, strong) void (^beginMessage)(NSString *transcription);
@property (nonatomic, strong) void (^continueMessage)(NSString *transcription);
@property (nonatomic, strong) void (^endMessage)(NSString *transcription);

- (instancetype)initWithLocale:(NSLocale *)locale;

- (void)start;
- (void)stop;

@end
