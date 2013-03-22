//
//  DocumentListTableViewController+Making.h
//  MultiDocument
//
//
// This version of MultiDocument derives from Rich Warren's work.
// See: http://www.freelancemadscience.com/fmslabs_blog/2011/12/19/syncing-multiple-core-data-documents-using-icloud.html
//
//  Modified by Don Briggs on 2013 March 22.
//  Copyright (c) 2013.
//

#import "DocumentListTableViewController.h"

@interface DocumentListTableViewController (Making)



+(UIManagedDocument*)instantiateDocumentFromRecord: (NSDictionary*)record;
+(NSDictionary*)persistentStoreOptionsForDocumentFileURL: (NSURL*)documentFileURL;

-(void)saveCreatingSaveOverwriting: (UIManagedDocument*)document
                       initializor: (NSInvocation*)initializor // e.g. -(void)addGraphOfObjectsTo: (UIManagedDocument*)document
                   successCallback: (NSInvocation*)successCallback // e.g. -(void)didIt
                      failCallback: (NSInvocation*)failCallback; // e.g. -(void)failed:(SEL)cmd error:(NSError*)error

-(void)establishDocument: (UIManagedDocument*)document
         successCallback: (NSInvocation*)successCallback
            failCallback: (NSInvocation*)failCallback;
@end
