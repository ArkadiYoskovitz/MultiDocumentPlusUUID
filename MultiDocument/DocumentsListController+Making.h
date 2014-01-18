//
//  DocumentsListController+Making.h
//  MultiDocumentPlusUUID

//
//
// MultiDocumentPlusUUID derives from Rich Warren's MultiDocument example.
// See: http://www.freelancemadscience.com/fmslabs_blog/2011/12/19/syncing-multiple-core-data-documents-using-icloud.html
//
//  Modified by Don Briggs on 2013 March 22.
//  Copyright (c) 2013.
//

#import "DocumentsListController.h"

@interface DocumentsListController (Making)

// Speculative:


-(void)observeDocument:(UIManagedDocument*)document;

-(void)mostlyHarmlessMethod: (NSString*)haplessArgument;

-(UIManagedDocument*)instantiateDocumentFromRecord: (NSDictionary*)record;
//+(NSDictionary*)persistentStoreOptionsForDocumentFileURL: (NSURL*)documentFileURL;
+(NSDictionary*)persistentStoreOptionsForRecord: (NSDictionary*)record;

-(void)establishDocument: (UIManagedDocument*)document
         successCallback: (NSInvocation*)successCallback
            failCallback: (NSInvocation*)failCallback;
@end