//
//  NSDictionary+NPAssisting.m
//  MultiDocument
//
//  Created by Don Briggs on 1/15/14.
//  Copyright (c) 2014 Don Briggs. All rights reserved.
//

#import "NSDictionary+NPAssisting.h"

#import "UIDocument+NPExtending.h"

//#import <UIKit/UIKit.h>

const NSString* NPLocalDocURLKey     = @"Local Document URL";
const NSString* NPCloudDocURLKey     = @"Cloud Document URL";
const NSString* NPCloudLogFilesURLKey     = @"Cloud Log Files URL";
const NSString* NPUUIDKey         = @"UUID";
const NSString* NPStoreOptionsKey = @"Persistent Store Options dictionary";


const NSString* NPMetadataItemKey = @"NSMetadataItem";
const NSString* NPMetadataDictionaryKey     = @"Metadata from Query Result Item";

const NSString* NPFileNameKey     = @"File Name";

const NSString* NPDocumentKey     = @"Document";

const NSString* NPMostRecentUpdateKey = @"Most Recent Update to psc";

//    The document's record stores the document's observers.

const NSString* NPDocumentPscImportObserverKey =
@"NSPersistentStoreDidImportUbiquitousContentChangesNotification Observer";
const NSString* NPDocumentStateChangedObserverKey = @"UIDocumentStateChangedNotification Observer";


@implementation NSDictionary (NPAssisting)

-(NSString*)fileSizeOfURL: (NSURL*)url
{
    NSDictionary *fileAttribs =
    [[NSFileManager defaultManager] attributesOfItemAtPath:[url path]
                                                     error:nil];
    NSNumber *size = [fileAttribs objectForKey:NSFileSize];
    NSString *sizeString = [NSString stringWithFormat:@"%@ bytes", [size stringValue]];

    return sizeString;
}
- (void)logAllCloudStorageKeysForMetadataItem:(NSMetadataItem *)item
{
    /*
     Good idea from: http://stackoverflow.com/questions/17129946/setting-up-nsmetadataquerydidupdatenotification-for-a-simple-response
     */
    NSNumber *isUbiquitous           = [item valueForAttribute:NSMetadataItemIsUbiquitousKey];
    NSNumber *hasUnresolvedConflicts = [item valueForAttribute:NSMetadataUbiquitousItemHasUnresolvedConflictsKey];
    NSNumber *isDownloaded           = [item valueForAttribute:NSMetadataUbiquitousItemIsDownloadedKey];
    NSNumber *isDownloading          = [item valueForAttribute:NSMetadataUbiquitousItemIsDownloadingKey];
    NSNumber *isUploaded             = [item valueForAttribute:NSMetadataUbiquitousItemIsUploadedKey];
    NSNumber *isUploading            = [item valueForAttribute:NSMetadataUbiquitousItemIsUploadingKey];
    NSNumber *percentDownloaded      = [item valueForAttribute:NSMetadataUbiquitousItemPercentDownloadedKey];
    NSNumber *percentUploaded        = [item valueForAttribute:NSMetadataUbiquitousItemPercentUploadedKey];

    NSURL *url = [item valueForAttribute:NSMetadataItemURLKey];
    
    BOOL documentExists = [[NSFileManager defaultManager] fileExistsAtPath:[url path]];
    NSLog(@"%@", [url lastPathComponent]);
    NSLog(@"%@", url.path);
    
    NSLog(@"isUbiquitous:%@ \nhasUnresolvedConflicts:%@ \nisDownloaded:%@ \nisDownloading:%@ \nisUploaded:%@ \nisUploading:%@ \n%%downloaded:%@ \n%%uploaded:%@ \ndocumentExists:%i \n%@", isUbiquitous, hasUnresolvedConflicts, isDownloaded, isDownloading, isUploaded, isUploading, percentDownloaded, percentUploaded, documentExists, url);
}
-(BOOL)npCreatedLocally
{
    NSMetadataItem *metadataItem = self[NPMetadataItemKey];
    
    return ( nil == metadataItem );
}
-(NSURL*)npTargetDocURL
{
    if( [self npCreatedLocally] ){
        return self[NPLocalDocURLKey];
    }else{
        return self[NPCloudDocURLKey];
    }
}
-(NSString*)npStatus
{
    NSMutableArray *components = [NSMutableArray arrayWithCapacity: 8];
    
    NSString *fileName = self[NPFileNameKey];
    [components addObject: fileName];
    
    UIDocument *doc = self[NPDocumentKey];
    if( nil == doc ){
        [components addObject: @"<nil>"];
    }else{
        [components addObject: [doc npDocumentStateAsString]];
    }
    
    NSMetadataItem *metadataItem = self[NPMetadataItemKey];

    
    if( [self npCreatedLocally] ){
        [components addObject: @"Created"];
        
    }else{
        // diagnostics, exploring API:
        [self logAllCloudStorageKeysForMetadataItem:metadataItem];
        
        [components addObject: @"Discovered"];
        
        NSArray *appleStatus =
        @[NSMetadataUbiquitousItemDownloadingStatusCurrent,
          NSMetadataUbiquitousItemDownloadingStatusDownloaded,
          NSMetadataUbiquitousItemDownloadingStatusNotDownloaded];
        
        NSString *status = [metadataItem valueForKey: NSMetadataUbiquitousItemDownloadingStatusKey];
        
        NSUInteger index = [appleStatus indexOfObject: status];
        NSArray *npStatus =
        @[@"Current",
          @"Downloaded",
          @"Not Downloaded"];
        
        [components addObject: [npStatus objectAtIndex: index]];
        
        NSNumber *pctDn = [metadataItem valueForKey: NSMetadataUbiquitousItemPercentDownloadedKey];
        
        if( nil != pctDn ){
            
            NSString *pctDnString =
            [NSString stringWithFormat: @"%@%c Dn",
             [pctDn stringValue], '%'];
            
            [components addObject:pctDnString];
        }
    }
    
    return [components componentsJoinedByString: @", "];
}
-(BOOL)isDocumentViewable
{
    UIDocument *doc = self[NPDocumentKey];
    if( nil == doc ){
        return NO;
    }
    
    enum UIDocumentState state = [doc documentState];
    if( state & UIDocumentStateClosed ){
        return NO;
    }
    
    // This test is specific to this application, not general.
    // See -[DocumentsListController(Making) observeDocument:],
    // and the observer for NSPersistentStoreDidImportUbiquitousContentChangesNotification.
    // On the first import, we add to the record the current date
    // as the value for NPMostRecentUpdateKey.
    // More generally, such an observer might post a notification of its first import,
    // with the document as the notification's object.
    NSDate *test = self[NPMostRecentUpdateKey];
    BOOL updated = (nil != test);
    if( !updated ){
        return  NO;
    }
    
    NSMetadataItem *metadataItem = self[NPMetadataItemKey];
    
    if( [self npCreatedLocally] ){
        return YES;;
    }
    
    NSString *status = [metadataItem valueForKey: NSMetadataUbiquitousItemDownloadingStatusKey];
    
    BOOL downloaded =
    [NSMetadataUbiquitousItemDownloadingStatusDownloaded isEqualToString: status];
    BOOL current =
    [NSMetadataUbiquitousItemDownloadingStatusCurrent    isEqualToString: status];
    
    if( downloaded || current ){
        return YES;
    }
    
    return NO;
    
}


@end
