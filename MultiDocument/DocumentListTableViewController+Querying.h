//
//  DocumentListTableViewController+Querying.h
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

@interface DocumentListTableViewController (Querying)

@property (readonly, strong) NSMetadataQuery *query;

#pragma mark - Loading Files

-(void)discoverLocalDocs;

-(void)launchMetadataQuery;
-(void)ignoreMetadataQuery;

- (void)processQueryUpdate;
- (void)addNewFilesToList:(NSArray*)queryItems;

@end
