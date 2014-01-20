//
//  DocumentsListController+ErrorRecovering.h
//  MultiDocument
//
//  Created by Don Briggs on 9/26/13.
//  Copyright (c) 2014 Don Briggs. All rights reserved.
//

#import "DocumentsListController.h"

@interface DocumentsListController (ErrorRecovering)
+(DocumentsListController*)activeController;
+(void)setActiveController: (DocumentsListController*)activeInstance;
-(Class)factory;

/**
  The method -closeReopen:onError: is untested.
 */
-(void)closeReopen: (UIManagedDocument*)haplessDocument
           onError: (NSError*)error;
@end