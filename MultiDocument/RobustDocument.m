//
//  RobustDocument.m
//  MultiDocument
//
//  Created by DevGuy on 9/20/13.
//  Copyright (c) 2013 Freelance Mad Science Labs. All rights reserved.
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
            
            if (didCancel){
                
                NSLog(@"User cancelled alert.");

            }else{
                
                switch (selectedIndex) {
                    
                    case 1:
                    {
                        NSLog(@"User clicked [Crash, Burn]");
                        exit(-1);
                        break;
                    }
                    default:
                        NSLog(@"Programming error: selected index = %d ", selectedIndex);
                        
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
