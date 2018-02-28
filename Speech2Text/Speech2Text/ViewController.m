//
//  ViewController.m
//  Speech2Text
//
//  Created by Igor Mikheiko on 14.02.18.
//  Copyright © 2018 *instinctools. All rights reserved.
//

#import "ViewController.h"
#import "MessageRecognizer.h"

@interface ViewController ()

@property (nonatomic, weak) IBOutlet UITextView *textView;
@property (nonatomic, weak) IBOutlet UITextView *debugTextView;
@property (nonatomic, strong) MessageRecognizer *recognizer;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.debugTextView.text = nil;
    
    __weak typeof(self) weakSelf = self;
    
    self.recognizer = [[MessageRecognizer alloc] initWithLocale:[NSLocale localeWithLocaleIdentifier:@"ru_RU"]];
    
    self.recognizer.beginMessage = ^(NSString *transcription) {
        weakSelf.textView.text = transcription;
    };
    
    self.recognizer.continueMessage = ^(NSString *transcription) {
        weakSelf.textView.text = transcription;
    };
    
    self.recognizer.endMessage = ^(NSString *transcription) {
        weakSelf.textView.text = nil;
        
        if (weakSelf.debugTextView.text.length) {
            weakSelf.debugTextView.text = [NSString stringWithFormat:@"%@\nMessage: %@", weakSelf.debugTextView.text, transcription];
        } else {
            weakSelf.debugTextView.text = [NSString stringWithFormat:@"Message: %@", transcription];
        }
    };
    
    [self.recognizer start];
}

@end
