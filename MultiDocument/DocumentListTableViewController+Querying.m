//
//  DocumentListTableViewController+Querying.m
//  MultiDocument
//
//
// This version of MultiDocument derives from Rich Warren's work.
// See: http://www.freelancemadscience.com/fmslabs_blog/2011/12/19/syncing-multiple-core-data-documents-using-icloud.html
//
//  Modified by Don Briggs on 2013 March 22.
//  Copyright (c) 2013.
//

#import "DocumentListTableViewController+Querying.h"
#import "DocumentListTableViewController+Making.h"
#import "DocumentListTableViewController+Resources.h"

#import "NSURL+NPAssisting.h"

#import <CoreData/CoreData.h>

@implementation DocumentListTableViewController (Querying)

@dynamic query;

#pragma mark - Loading Files
-(void)observeQuery
{

    NSOperationQueue *mainQueue = [NSOperationQueue mainQueue];
    
    NSNotificationCenter* center =
    [NSNotificationCenter defaultCenter];
    
    id observer =
    [center addObserverForName:NSMetadataQueryDidFinishGatheringNotification
                        object: self.query
                         queue:mainQueue
                    usingBlock:^(NSNotification* notification) {
                        
                        [self.query disableUpdates];{
                            NSLog(@"NSMetadataQuery finished gathering, found %d files",
                                  [self.query resultCount]);
                         }[self.query enableUpdates];
                        
                    }];
    
    [self.notifications addObject:observer];
    
    observer =
    [center addObserverForName:NSMetadataQueryDidUpdateNotification
                        object: self.query
                         queue:mainQueue
                    usingBlock:^(NSNotification *note) {
                        
                        NSLog(@"Update notification received. %d files found so far",
                              [self.query resultCount]);
                        
                        [self processQueryUpdate];
                        
                    }];
    
    [self.notifications addObject:observer];
    
    
    observer =
    [center addObserverForName:NSMetadataQueryGatheringProgressNotification
                        object: self.query
                         queue:mainQueue
                    usingBlock:^(NSNotification *note) {
                        
                        NSLog(@"Progress notification received. %d files found so far",
                              [self.query resultCount]);
                        
                        [self processQueryUpdate];
                        
                    }];
    
    [self.notifications addObject:observer];

}
const NSString *PNDocMDataDotPlistKey = @"DocumentMetadata.plist";

-(NSMetadataQuery*)query
{
    if( nil == m_query ){
        m_query = [[NSMetadataQuery alloc] init];
        
        [m_query setSearchScopes:
         [NSArray arrayWithObjects:
          NSMetadataQueryUbiquitousDataScope, NSMetadataQueryUbiquitousDocumentsScope, nil]];
        
        // We cannot look for the folder--must look for the
        // contained DocumentMetadata.plist.
        NSPredicate *p =
        [NSPredicate predicateWithFormat:@"%K like %@",
         NSMetadataItemFSNameKey, PNDocMDataDotPlistKey];
        
        [m_query setPredicate:p];
        
        [self observeQuery];
    }
    return m_query;
}

-(void)discoverLocalDocs
{
    // get all the files
    NSDirectoryEnumerator *dirEnumerator =
    [[[self class ] fileManager] enumeratorAtURL: [[self class] localDocsURL]
                      includingPropertiesForKeys:nil
                                         options: 0
                                    errorHandler: nil];
    
    for( NSURL *nextURL in dirEnumerator ){
        
        NSURL *normalizedURL = [nextURL npNormalizedURL];
        NSString * filename = [normalizedURL lastPathComponent];
        NSURL *urlDir = [normalizedURL URLByDeletingLastPathComponent];
        NSString *uuid = [urlDir lastPathComponent];
        
        if( [self validUuidString: uuid] ){
            
            NSMutableDictionary *record =
            [self enrollFilename: filename
                            uuid: uuid];
            
            NSAssert( [[[record objectForKey: NPLocalURLKey] absoluteString]
                        isEqualToString:
                        [normalizedURL absoluteString]],
                     @"Mismatched URLs: \n%@ \n%@",
                     [[record objectForKey: NPLocalURLKey] absoluteString],
                     [normalizedURL absoluteString]);
            
            [self addDocumentFromRecord: record
                         documentExists: YES];
            
            [dirEnumerator skipDescendants];
        }
    }
}

-(void)launchMetadataQuery
{    
    [self.query startQuery];
    [self.query enableUpdates];
}

-(void)ignoreMetadataQuery
{
    
    [self.query stopQuery];
    
    NSNotificationCenter* center =
    [NSNotificationCenter defaultCenter];
    
    for (id observer in self.notifications) {
        
        [center removeObserver:observer];
    }
    
    m_query = nil;

}
- (void)processQueryUpdate {
    
    [self.query disableUpdates];{
        
        NSUInteger currentCount = [self.docRecords count];
        NSUInteger updateCount = [self.query resultCount];
        
        NSLog(@"-processUpdate: count: %d -> %d", currentCount, updateCount );
        [self addNewFilesToList:self.query.results];
        
        
    }[self.query enableUpdates];
}
- (void)addNewFilesToList:(NSArray*)queryItems
{
    
    NSUInteger count = [queryItems count];
    if (count == 0) return;
    
    // open the files in a background thread
    dispatch_queue_t queue =
    dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_async(queue, ^{
        
        for (NSMetadataItem* item in queryItems) {
            
            NSURL* url = [item valueForAttribute:NSMetadataItemURLKey];
            
            NSFileCoordinator* coordinator =
            [[NSFileCoordinator alloc] initWithFilePresenter:nil];
            
            // always wrap any read/write operations
            // in an appropriate coordinator
            [coordinator coordinateReadingItemAtURL:url
                                            options:NSFileCoordinatorReadingWithoutChanges
                                              error:nil
                                         byAccessor:^(NSURL *metadataPlistURL) {
                                             
                                             NSLog(@"metadataPlistURL = %@",
                                                   [metadataPlistURL absoluteString] );
                                             
                                             // metadataPlistURL should be:
                                             // <cloudContainer>/<uuid>/foo/DocumentMetadata.plist.
                                             
                                             
                                             // [1] Strip off /DocumentMetadata.plist to get its document's URL.
                                             NSURL *targetDocURL = [metadataPlistURL URLByDeletingLastPathComponent];
                                             
                                             
                                             // [2] unpack the dictionary.
                                             NSDictionary* metadata =
                                             [NSDictionary dictionaryWithContentsOfURL:metadataPlistURL];
                                             if( nil == metadata ){
                                                 
                                                 // Stuff happens:
                                                 // You can easily get nil dictionaries:
                                                 // just delete cloud storage
                                                 // (e.g., Mac OS X System Preferences->iCloud->Manage...->MyApp-> Delete All,
                                                 // then run again.
                                                 
                                                 NSLog( @"got nil dictionary");
                                                 
                                             }else{
                                                 
                                                 NSAssert( [metadata isKindOfClass: [NSDictionary class]],
                                                          @"Bogus dictionary (dict).");
                                                 
                                                 
                                                 // [3] check the ubiquitous content name:
                                                 NSString *ucName =
                                                 [metadata objectForKey:NSPersistentStoreUbiquitousContentNameKey];
                                                 // ucn should be a uuid
                                                 
                                                 NSAssert( (nil != ucName), @"No value for NSPersistentStoreUbiquitousContentNameKey");
                                                 
                                                 //NSString *targetName = [targetDocURL lastPathComponent];
                                                 NSString *uuid =
                                                 [[targetDocURL URLByDeletingLastPathComponent] lastPathComponent];
                                                 //targetName = targetName; // suppress compiler warning
   
                                                 NSAssert( [uuid isEqualToString: ucName],
                                                          @"uuid = %@ \n ucName = %@\n value for NSPersistentStoreUbiquitousContentNameKey",
                                                          uuid,
                                                          ucName);
                                                 
                                                 // [4] Enroll it:
                                                 NSLog(@"targetDocURL = %@",
                                                       [targetDocURL absoluteString] );
                                                  
                                                 NSMutableDictionary __block *record = [self recordForUuid: uuid];
                                                 
                                                 if( nil == record ){
                                                     
                                                     /*
                                                      If we don't already have a record for this uuid, make a new one.
                                                       */

                                                     dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                                         
                                                         record =
                                                         [self enrollMetadataItem: item];
                                                         
                                                         [self addDocumentFromRecord: record
                                                                      documentExists: YES];
                                                     });
                                                     
                                                  }
                                             }
                                             
                                         }]; // end of coordinator block
            
        }   // end of the for loop iterating over query items
        
    });  // end of dispatch_async block
    
}


@end
