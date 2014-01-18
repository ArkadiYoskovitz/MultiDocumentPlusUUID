//
//  DocumentsListController+Querying.h
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

@interface DocumentsListController (Querying)

@property (readonly, strong) NSMetadataQuery *query;

#pragma mark - Loading Files

//-(void)discoverLocalDocs; // No: limit the scope of this example.

-(void)launchMetadataQuery;
-(void)ignoreMetadataQuery;

- (void)processQueryUpdate;
- (void)enrollDocumentsFromQueryResults:(NSArray*)queryItems;

@end
