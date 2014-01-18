//
//  UIBAlertView.m
//  UIBAlertView
//
//  Created by Stav Ashuri on 1/31/13.
//  Copyright (c) 2013 Stav Ashuri. All rights reserved.
//

/**
 See: https://github.com/stavash/UIBAlertView
 
 License
 Copyright (c) 2013 Stav Ashuri
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "UIBAlertView.h"

@interface UIBAlertView() <UIAlertViewDelegate>

@property (strong, nonatomic) UIBAlertView *strongAlertReference;

@property (copy) AlertDismissedHandler activeDismissHandler;

@property (strong, nonatomic) NSString *activeTitle;
@property (strong, nonatomic) NSString *activeMessage;
@property (strong, nonatomic) NSString *activeCancelTitle;
@property (strong, nonatomic) NSString *activeOtherTitles;
@property (strong, nonatomic) UIAlertView *activeAlert;

@end

@implementation UIBAlertView

#pragma mark - Public (Initialization)

- (id)initWithTitle:(NSString *)aTitle
            message:(NSString *)aMessage
  cancelButtonTitle:(NSString *)aCancelTitle
  otherButtonTitles:(NSString *)otherTitles,... {
    self = [super init];
    if (self) {
        UIAlertView *alert =
        [[UIAlertView alloc] initWithTitle:aTitle
                                   message:aMessage
                                  delegate:self
                         cancelButtonTitle:aCancelTitle
                         otherButtonTitles:nil];
        
        if (otherTitles != nil) {
            [alert addButtonWithTitle:otherTitles];
            va_list args;
            va_start(args, otherTitles);
            NSString * title = nil;
            while((title = va_arg(args,NSString*))) {
                [alert addButtonWithTitle:title];
            }
            va_end(args);
        }
        self.activeAlert = alert;
    }
    return self;
}

#pragma mark - Public (Functionality)

- (void)showWithDismissHandler:(AlertDismissedHandler)handler {
    self.activeDismissHandler = handler;
    self.strongAlertReference = self;
    [self.activeAlert show];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView
clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (self.activeDismissHandler) {
        self.activeDismissHandler(buttonIndex,buttonIndex == alertView.cancelButtonIndex);
    }
    self.strongAlertReference = nil;
}

@end
