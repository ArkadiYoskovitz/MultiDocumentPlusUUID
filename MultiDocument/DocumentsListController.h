//
//  DocumentsListController.h
//  MultiDocumentPlusUUID

//
//
// MultiDocumentPlusUUID derives from Rich Warren's MultiDocument example.
// See: http://www.freelancemadscience.com/fmslabs_blog/2011/12/19/syncing-multiple-core-data-documents-using-icloud.html
//
//  Modified by Don Briggs on 2013 March 22.
//  Copyright (c) 2013.
//

#import <UIKit/UIKit.h>

extern NSString* NPLocalDocURLKey;
extern NSString* NPCloudDocURLKey;
extern NSString* NPCloudLogFilesURLKey;
extern NSString* NPUUIDKey;
extern NSString* NPStoreOptionsKey;

extern NSString* NPMetadataItemKey;
extern NSString* NPMetadataDictionaryKey;
extern NSString* NPFileNameKey;
extern NSString* NPDocumentKey;

@class UIManagedDocument;

@interface DocumentsListController : UITableViewController
{
    NSMutableOrderedSet *m_docRecords;
    NSMutableArray* m_notifications;
    NSMetadataQuery* m_query;
    NSMutableArray *m_notificationObservers;

}

@property (readonly, strong) NSMutableOrderedSet* docRecords;
@property (readonly, strong) NSMutableArray* notificationObservers;

@property (readwrite, strong) IBOutlet UIBarButtonItem* addButton;



#pragma mark IBActions:
- (IBAction)addDocument:(id)sender;
-(void)addDocumentFromRecord: (NSMutableDictionary*)record;

#pragma mark addDocumentFromRecord:documentExists: callbacks:

-(void)didAddDocument: (UIManagedDocument*)document;
-(void)didFailToAddDocument: (UIManagedDocument*)document;
-(void)didOpenDocument: (UIManagedDocument*)document;

-(void)didFailToOpenDocument: (UIManagedDocument*)document;

#pragma mark Utility methods:
-(BOOL)validUuidString: (NSString*)testUuidString;
-(NSMutableDictionary*)recordForUuid: (NSString*)uuid;

#pragma mark Model-Controller methods:
-(NSMutableDictionary*)recordEnrolledForFilename: (NSString*)filename
                                 uuid: (NSString*)uuid;

-(NSMutableDictionary*)enrollMetadataItem: (NSMetadataItem*)metadataItem;

-(NSMutableDictionary*)recordForDocument: (UIManagedDocument*)document;

#pragma mark Model Operations 

-(void)addObjectGraphToDocument: (UIManagedDocument*)document;

@end
