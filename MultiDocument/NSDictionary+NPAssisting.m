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

const NSString *NPDocumentMetadataDotPlist = @"DocumentMetadata.plist";

const NSString* NPLocalDocURLKey     = @"Local Document URL";
const NSString* NPCloudDocURLKey     = @"Cloud Document URL";
const NSString* NPCloudLogFilesURLKey     = @"Cloud Log Files URL";

const NSString* NPLocalDocPersistentStoreURLKey = @"Local Document Persistent Store URL";
const NSString* NPCloudDocPersistentStoreURLKey = @"Cloud Document Persistent Store URL";

const NSString* NPLocalDocumentMetadataPlistURLKey = @"Local DocumentMetadata.plist URL";

const NSString* NPCloudDocumentMetadataPlistURLKey= @"Cloud DocumentMetadata.plist URL";


const NSString* NPUUIDKey         = @"UUID";

const NSString* NPLocalStoreOptionsKey = @"Local Persistent Store Options dictionary";
const NSString* NPCloudStoreOptionsKey = @"Cloud Persistent Store Options dictionary";
//const NSString* NPLocalStoreContentPersistentStoreURLKey = @"Local Store URL";


const NSString* NPSuccessCallbackKey = @"Success Callback";
const NSString* NPFailureCallbackKey = @"Failure Callback";


const NSString* NPMetadataItemKey = @"NSMetadataItem";
const NSString* NPMetadataDictionaryKey     = @"Metadata from Query Result Item";

const NSString* NPFileNameKey     = @"File Name";

const NSString* NPDocumentKey     = @"Document";

const NSString* NPNotificationDates = @"Notification Dates";

const NSString* NPStealthyDidFinishImport = @"com.apple.coredata.ubiquity.importer.didfinishimport";

const NSString* NPDocumentPscImportObserverKey =
@"NSPersistentStoreDidImportUbiquitousContentChangesNotification Observer";

const NSString* NPDocumentStealthyImportObserverKey =
@"NPDocumentStealthyImportObserverKey";


const NSString* NPDocumentPscStoresWillChangeObserverKey = @"NSPersistentStoreCoordinatorStoresWillChangeNotification Observer";

const NSString* NPDocumentPscStoresDidChangeObserverKey = @"NSPersistentStoreCoordinatorStoresDidChangeNotification Observer";

const NSString* NPDocumentStateChangedObserverKey = @"UIDocumentStateChangedNotification Observer";

const NSString* NPDocumentMocObjectsChangedObserverKey = @"NSManagedObjectContextObjectsDidChangeNotification Observer";

@implementation NSDictionary (NPAssisting)

-(NSString*)fileSizeOfURL: (NSURL*)url
{
    NSDictionary *fileAttribs =
    [[NSFileManager defaultManager] attributesOfItemAtPath:[url path]
                                                     error:nil];
    NSNumber *size = fileAttribs[NSFileSize];
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
    NSString *downloadingStatus      = [item valueForAttribute:NSMetadataUbiquitousItemDownloadingStatusKey];
    NSNumber *isDownloading          = [item valueForAttribute:NSMetadataUbiquitousItemIsDownloadingKey];
    NSNumber *isUploaded             = [item valueForAttribute:NSMetadataUbiquitousItemIsUploadedKey];
    NSNumber *isUploading            = [item valueForAttribute:NSMetadataUbiquitousItemIsUploadingKey];
    NSNumber *percentDownloaded      = [item valueForAttribute:NSMetadataUbiquitousItemPercentDownloadedKey];
    NSNumber *percentUploaded        = [item valueForAttribute:NSMetadataUbiquitousItemPercentUploadedKey];

    NSURL *url = [item valueForAttribute:NSMetadataItemURLKey];
    
    BOOL documentExists = [[NSFileManager defaultManager] fileExistsAtPath:[url path]];
    NSLog(@"%@", [url lastPathComponent]);
    NSLog(@"%@", url.path);
    
    NSLog(@"isUbiquitous:%@ \nhasUnresolvedConflicts:%@ \nisDownloaded:%@ \ndownloadingStatus:%@ \nisUploaded:%@ \nisUploading:%@ \n%%downloaded:%@ \n%%uploaded:%@ \ndocumentExists:%i \n%@",
          isUbiquitous,      hasUnresolvedConflicts,    isDownloading,     downloadingStatus, isUploaded, isUploading, percentDownloaded, percentUploaded, documentExists, url);
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
        
        [components addObject: npStatus[index]];
        
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
    
    // A locally created document that is not [Closed] should be viewable
    if( [self npCreatedLocally] ){
        return YES;
    }
    
    // When is the object graph of a disovered document avalable for inspection?
    // The entire dictionary named NPNotificationDates may be overkill,
    // because the pertinent signal seems to be the arrival of the notification named
    // "com.apple.coredata.ubiquity.importer.didfinishimport".
    // See also: -[DocumentsListController+Making receivedNotification:document:]
    NSDictionary *notificationDates = self[NPNotificationDates];
    if( nil != notificationDates ){
        
        // e.g.,
        // notificationDates =
        // {
        //     NSObjectsChangedInManagingContextNotification = "2014-02-06 20:01:12 +0000";
        //     "com.apple.coredata.ubiquity.importer.didfinishimport" = "2014-02-06 20:03:04 +0000";
        // }

//        id test1 = notificationDates[NSPersistentStoreCoordinatorStoresDidChangeNotification];
//        if( nil != test1 ){
//            return YES;
//        }
        id test2 = notificationDates[NPStealthyDidFinishImport];
        if( nil != test2 ){
            return YES;
        }

    }
    
    return NO;
    
}

@end
