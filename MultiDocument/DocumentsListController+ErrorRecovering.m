//
//  DocumentsListController+ErrorRecovering.m
//  MultiDocument
//
//  Created by Don Briggs on 9/26/13.
//  Copyright (c) 2014 Don Briggs. All rights reserved.
//

#import "DocumentsListController+ErrorRecovering.h"
#import "DocumentsListController+Making.h"
#import "RobustDocument.h"

#import "NSDictionary+NPAssisting.h"

NSString *NPErrorRecoveryEnabledKey = @"errorRecoveryEnabled";

@implementation DocumentsListController (ErrorRecovering)
static DocumentsListController *mm_activeController = nil;


+(DocumentsListController*)activeController
{
    return mm_activeController;
}
+(void)setActiveController: (DocumentsListController*)activeInstance
{
    mm_activeController = activeInstance;
}
-(Class)factory
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    BOOL errorRecoveryEnabled = [userDefaults boolForKey: NPErrorRecoveryEnabledKey];

    [DocumentsListController setActiveController: self];
    
    Class factory = nil;
    
    if( errorRecoveryEnabled ){
        factory = [RobustDocument class];
    }else{
        factory = [UIManagedDocument class];
    }
    return factory;
}


-(void)closeDetailView
{
    UINavigationController *nav = [self navigationController];
    [nav popToRootViewControllerAnimated: YES];
}

/**
 The method -closeReopen:onError: is untested.
 */
-(void)closeReopen: (UIManagedDocument*)haplessDocument
           onError: (NSError*)error
{
    NSLog(@"-[DocumentsListController closeReopen:]");
    
    [self closeDetailView];
    NSMutableDictionary *record = [self recordForDocument: haplessDocument].mutableCopy;
    
    [haplessDocument closeWithCompletionHandler:^(BOOL success){
        if(success){
            
            
            [record removeObjectForKey: NPDocumentKey];
            UIManagedDocument *document2 = [self instantiateDocumentFromRecord: record];
            record[NPDocumentKey] = document2;
            [self updateRecord: record];
            
            [document2 openWithCompletionHandler:^(BOOL success){
                
                if(success){
                    NSLog(@"Re-opened successfully.");
                }else{
                    NSLog(@"Jelly side down...");
                }
                [haplessDocument finishedHandlingError: error
                                             recovered: success];
            }];
        }else{
            NSLog(@"Could not close, let alone re-open, document: %@",
                  record[NPCloudDocURLKey] );
            NSLog(@"Might as well touch [Crash, Burn]");
            exit(-1);
        }
    }];
}

@end
