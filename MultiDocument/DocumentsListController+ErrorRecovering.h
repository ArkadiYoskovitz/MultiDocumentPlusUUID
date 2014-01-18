//
//  DocumentsListController+ErrorRecovering.h
//  MultiDocument
//
//  Created by DevGuy on 9/26/13.
//  Copyright (c) 2013 Freelance Mad Science Labs. All rights reserved.
//

#import "DocumentsListController.h"

@interface DocumentsListController (ErrorRecovering)
+(DocumentsListController*)activeController;
+(void)setActiveController: (DocumentsListController*)activeInstance;
-(Class)factory;
-(void)closeReopen: (UIManagedDocument*)haplessDocument
           onError: (NSError*)error;
@end