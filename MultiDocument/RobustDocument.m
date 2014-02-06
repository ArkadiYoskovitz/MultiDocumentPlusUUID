//
//  RobustDocument.m
//  MultiDocument
//
//  Created by Don Briggs on 9/20/13.
//  Copyright (c) 2014 Don Briggs. All rights reserved.
//

#import "UIBAlertView.h"

#import "RobustDocument.h"

//#import "DocumentsListController+Making.h"

#import "DocumentsListController+ErrorRecovering.h"

@implementation RobustDocument

-(void)        handleError:(NSError *)error
  userInteractionPermitted:(BOOL)userInteractionPermitted
{
    
    NSLog(@"-[RobustDocument handleError:userInteractionPermitted:]");
    
    if( userInteractionPermitted ){
        UIBAlertView *alert =
        [[UIBAlertView alloc] initWithTitle:@"Core Data Error"
                                    message: [error description]
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:@"Crash, Burn",
         nil];
        
        [alert showWithDismissHandler:^(NSInteger selectedIndex, BOOL didCancel) {
            
            if (didCancel){ // @"OK"
                
                NSLog(@"User cancelled alert.");

            }else{
                
                switch (selectedIndex) {
                    
                    case 1: // @"Crash, Burn"
                    {
                        NSLog(@"User clicked [Crash, Burn]");
                        
                        // This is where we might try error recovery.
                        
                        exit(-1); // But, ... no. Not now.
                        break;
                    }
                    default:
                        NSLog(@"Programming error: selected index = %ld ", (long)selectedIndex);
                        
                        break;
                }
            }
            
        }];
        
    }else{ // if( userInteractionPermitted )
        // NOT permitted:
        NSLog(@"User interaction NOT permitted");
        exit(-1);
    }
    
}
-(void)finishedHandlingError:(NSError *)error
                   recovered:(BOOL)recovered
{
        [super handleError: error
  userInteractionPermitted: recovered];
}
@end
