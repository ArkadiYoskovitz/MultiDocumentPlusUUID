//
//  DocumentsListController.h
//  MultiDocumentPlusUUID

//
//
// MultiDocumentPlusUUID derives from Rich Warren's MultiDocument example.
// See: http://www.freelancemadscience.com/fmslabs_blog/2011/12/19/syncing-multiple-core-data-documents-using-icloud.html
//
//  Modified by Don Briggs on 2013 March 22.
//  Copyright (c) 2014 Don Briggs. All rights reserved.
//

#import <UIKit/UIKit.h>

extern NSString* NPDocumentStateChangedObserverKey;

@class UIManagedDocument;

@interface DocumentsListController : UITableViewController
{
    NSMutableOrderedSet *m_docRecords;
    NSMutableArray* m_notifications;
    NSMetadataQuery* m_query;
    NSMutableArray *m_notificationObservers;

    NSTimer *m_tableViewSnoozeAlarm;
}

@property (readonly, strong) NSMutableOrderedSet* docRecords;
@property (readonly, strong) NSMutableArray* notificationObservers;

@property (readwrite, strong) IBOutlet UIBarButtonItem* addButton;

#pragma mark Workaround to refresh table view on main thread, later.

/**
    Call liberally. 
    When the snooze alarm eventually goes off,
    the table view reloads.
 */
-(void)resetTableViewSnoozeAlarm;

#pragma mark IBActions:
- (IBAction)addDocument:(id)sender;
-(void)addDocumentFromRecord: (NSDictionary*)record;

#pragma mark addDocumentFromRecord:documentExists: callbacks:

-(void)didAddDocument: (UIManagedDocument*)document;
-(void)didFailToAddDocument: (UIManagedDocument*)document;
-(void)didOpenDocument: (UIManagedDocument*)document;

-(void)didFailToOpenDocument: (UIManagedDocument*)document;

#pragma mark Utility methods:
-(BOOL)validUuidString: (NSString*)testUuidString;
-(NSDictionary*)recordForUuid: (NSString*)uuid;
-(void)updateRecord: (NSDictionary*)newRecord;

#pragma mark Model-Controller methods:
-(NSMutableDictionary*)recordEnrolledForFilename: (NSString*)filename
                                 uuid: (NSString*)uuid;

-(NSMutableDictionary*)enrollMetadataItem: (NSMetadataItem*)metadataItem;

-(NSMutableDictionary*)recordForDocument: (UIManagedDocument*)document;

#pragma mark Model Operations 

-(void)addObjectGraphToDocument: (UIManagedDocument*)document;

@end
