//
//  DocumentsListController.m
//  MultiDocumentPlusUUID

//
//
// MultiDocumentPlusUUID derives from Rich Warren's MultiDocument example.
// See: http://www.freelancemadscience.com/fmslabs_blog/2011/12/19/syncing-multiple-core-data-documents-using-icloud.html
//
//  Modified by Don Briggs on 2013 March 22.
//  Copyright (c) 2014 Don Briggs. All rights reserved.
//

#import "DocumentsListController.h"

#import "DocumentsListController+Making.h"
#import "DocumentsListController+Querying.h"
#import "DocumentsListController+Resources.h"

#import "DetailViewController.h"
//#import "DocumentCell.h"
#import <CoreData/CoreData.h>

#import "ModelVersion.h"

#import "TextEntry.h"

#import "NSURL+NPAssisting.h"

#import "UIDocument+NPExtending.h"

#import "NSDictionary+NPAssisting.h"

static NSString* const BaseFileName = @"TestDoc";


@interface DocumentsListController()        

- (NSUInteger)calculateNextFileNameIndex;
@end

@implementation DocumentsListController

@synthesize addButton;
@dynamic docRecords;

//@dynamic notificationObservers;


#pragma mark Property Accessors:

-(NSFileManager*)fileManager
{
    return [[self class] fileManager];
}
-(NSMutableOrderedSet*)docRecords
{
    /**
     
     Whenever we instantiate a document on this device,
     whether by creation or discovery,
     we add its record to the end of self.docRecords.
     
     */
    if( nil == m_docRecords ){
        m_docRecords = [[NSMutableOrderedSet alloc] initWithCapacity:8];
    }
    return m_docRecords;
}

-(NSMutableArray*)notificationObservers
{
    if( nil == m_notificationObservers ){
        m_notificationObservers = [[NSMutableArray alloc] initWithCapacity: 4];
    }
    return m_notificationObservers;
}

#pragma mark - View Controller methods


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle
-(void)observeWillTerminate
{
    NSNotificationCenter* center =
    [NSNotificationCenter defaultCenter];
    
    id observer =
    [center addObserverForName:UIApplicationWillTerminateNotification
                        object:[UIApplication sharedApplication]
                         queue:nil
                    usingBlock:^(NSNotification* notification) {
                        
                        [self closeDocuments];
                        [self ignoreMetadataQuery];
                    }];
    
    [self.notificationObservers addObject: observer];

}
static NSString *defaultCellReuseIdentifier = @"DefaultCell";
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[self tableView] registerClass:[UITableViewCell class]
             forCellReuseIdentifier:defaultCellReuseIdentifier];
    
    if ([[self class] isCloudEnabled]) {
        [self launchMetadataQuery];
    } else {
        //[self discoverLocalDocs]; // This app is limited.
    }
    
    
    [self observeWillTerminate];
}
-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self resetTableViewSnoozeAlarm];
}
-(void)closeDocuments
{
    for( NSDictionary *record in self.docRecords ){
        
        UIManagedDocument *document = record[NPDocumentKey];
        
        NSAssert( (nil != document), @"NPDocumentKey missing in record:\n%@",
                 [record description]);
        NSAssert( [document isKindOfClass: [UIManagedDocument class]],
                 @"Bogus document (%@) in record:\n%@",
                 NSStringFromClass([document class]),
                 [record description]);
        
        UIDocumentState state = document.documentState;
        
        NSAssert( (UIDocumentStateNormal == state),
                 @"document state = %lu",
                 (unsigned long)state );
        
        NSString *path = [document fileURL].path;
        [document closeWithCompletionHandler: ^(BOOL success) {
            if( success ){
                NSLog(@"closed %@", path);
            }else{
                NSLog(@"failed to close properly: %@", path);
                NSLog(@"document state = %lu",
                      (unsigned long)document.documentState);
            }
            
        }];
    }

}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}


#pragma mark - Table View Contents

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // We only have a single section
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section
{
    // Return the number of entries in the ordered set of dictionaries (each specifies a document).
    return [self.docRecords count];
}


-(void)configureCell: (UITableViewCell *)cell
                 row: (NSUInteger)row
{
    NSMutableDictionary *record = (self.docRecords)[row];
    cell.textLabel.text = [record npStatus];
    cell.detailTextLabel.text = record[NPFileNameKey];
    
    cell.userInteractionEnabled = [record isDocumentViewable];
}


- (void)tableView:(UITableView *)tableView
  willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath
{

    if( cell.userInteractionEnabled ){
        cell.backgroundColor = [UIColor whiteColor];
    }else{
        cell.backgroundColor = [UIColor lightGrayColor];
    }
}


- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell =
    [tableView dequeueReusableCellWithIdentifier: defaultCellReuseIdentifier];
    
    if( nil == cell ){
        cell = [[UITableViewCell alloc] initWithStyle: UITableViewCellStyleDefault
                                      reuseIdentifier: defaultCellReuseIdentifier];
    }
    [self configureCell: cell
                    row: indexPath.row];
    
    return cell;
}

-(void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView cellForRowAtIndexPath: indexPath];
    if( cell.userInteractionEnabled ){
        [self performSegueWithIdentifier:@"Open File Segue"
                                  sender:cell];
    }
}
#pragma mark - Helper

- (NSUInteger)calculateNextFileNameIndex {
    
    /**
     Calculate n for file names:
     
     <BaseFileName>n.
     */
    
    NSUInteger max = 0;
  
    for (NSDictionary* nextRecord in self.docRecords) {
        
        NSString *name = nextRecord[NPFileNameKey];
        
        NSString* numberSuffix =
        [name substringFromIndex:[BaseFileName length]];
        
        NSUInteger value = [numberSuffix integerValue];
        if (value > max) {
            max = value;
        }
    }

    return max + 1;
}

#pragma mark Model-Controller methods:

#pragma mark Document Records: an ordered set of dictionaries, each specifies a document, in order of creation or discovery

-(NSMutableDictionary*)mapUuidsToRecords
{
    NSMutableDictionary *map =
    [NSMutableDictionary dictionaryWithCapacity: self.docRecords.count];
    
    @synchronized ( self.docRecords ){
        for( NSDictionary *d in self.docRecords ){
            // local document records have no metadata.
            
            NSString *uuid = d[NPUUIDKey];
            map[uuid] = d;
        }
    }
    return map;
}


-(NSMutableDictionary*)recordForUuid: (NSString*)uuid
{
    NSMutableDictionary *map = [self mapUuidsToRecords];
    return  map[uuid];
}
/**
 This method retrieves a record for a uuid, or builds and stores an appropriate record for the uuid if no such record exists.
 
 Note that the MultiDocument app only adds documents;
 it never removes any.

 Example:
 (lldb) po record
 {
 "Cloud Document Persistent Store URL" = "file:///var/mobile/Library/Mobile%20Documents/YHVGV9RUH4~com~nowpicture~multidocument/Documents/89C68DD4-0F34-4CFB-8D57-89531B288979/TestDoc1/StoreContent.nosync";
 "Cloud DocumentMetadata.plist URL" = "file:///var/mobile/Library/Mobile%20Documents/YHVGV9RUH4~com~nowpicture~multidocument/Documents/89C68DD4-0F34-4CFB-8D57-89531B288979/TestDoc1/DocumentMetadata.plist";
 "Cloud Persistent Store Options dictionary" =     {
 NSInferMappingModelAutomaticallyOption = 1;
 NSMigratePersistentStoresAutomaticallyOption = 1;
 NSPersistentStoreUbiquitousContentNameKey = "89C68DD4-0F34-4CFB-8D57-89531B288979";
 NSPersistentStoreUbiquitousContentURLKey = "file:///var/mobile/Library/Mobile%20Documents/YHVGV9RUH4~com~nowpicture~multidocument/LogFiles";
 };
 "Document Cloud Sync URL" = "file:///var/mobile/Library/Mobile%20Documents/YHVGV9RUH4~com~nowpicture~multidocument/Documents/89C68DD4-0F34-4CFB-8D57-89531B288979/TestDoc1";
 "File Name" = TestDoc1;
 "Local Document Persistent Store URL" = "file:///var/mobile/Applications/1D7E3A9D-6F98-4831-BC4C-1F35BC7165A1/Documents/89C68DD4-0F34-4CFB-8D57-89531B288979/TestDoc1/StoreContent/persistentStore";
 "Local Document URL" = "file:///var/mobile/Applications/1D7E3A9D-6F98-4831-BC4C-1F35BC7165A1/Documents/89C68DD4-0F34-4CFB-8D57-89531B288979/TestDoc1";
 "Local DocumentMetadata.plist URL" = "file:///var/mobile/Applications/1D7E3A9D-6F98-4831-BC4C-1F35BC7165A1/Documents/89C68DD4-0F34-4CFB-8D57-89531B288979/TestDoc1/DocumentMetadata.plist";
 "Local Persistent Store Options dictionary" =     {
 NSInferMappingModelAutomaticallyOption = 1;
 NSMigratePersistentStoresAutomaticallyOption = 1;
 };
 UUID = "89C68DD4-0F34-4CFB-8D57-89531B288979";
 }
 
 
 @param filename a string suitable for a document's file name
 @param uuid     NSUUID in string form
 
 @return a dictionary
 */
-(NSDictionary*)recordEnrolledForFilename: (NSString*)filename
                                     uuid: (NSString*)uuid
{
    
    NSAssert( [self validUuidString: uuid], @"Bogus uuid: %@", uuid);
    NSAssert( (0 != filename.length), @"Bogus filename, empty");
    
    NSURL *localDocURL = [[self class] localDocURLForFileName: filename
                                                         uuid: uuid];
    NSURL *cloudDocURL = [[self class] cloudDocURLForFileName: filename
                                                         uuid: uuid];
    
    NSURL *uuidDir = [[localDocURL URLByDeletingLastPathComponent] absoluteURL];
    BOOL ok = [[self class] assureDirectoryURLExists: uuidDir];
    NSAssert( ok, @"Can't make directory: %@", [uuidDir absoluteString] );
    
    
    NSDictionary *existing = [self recordForUuid: uuid];
    
    
    if( nil != existing ){
        BOOL sanity = [filename isEqualToString: existing[NPFileNameKey]];
        
        NSAssert( sanity, @"Conflict: filenames %@ & %@ for uuid: %@",
                 filename,
                 existing[NPFileNameKey],
                 uuid);
        return existing;
        
    }else{
        NSMutableDictionary *record = nil;
        
        record = [NSMutableDictionary dictionaryWithCapacity: 8];
        
        record[NPUUIDKey] = uuid;
        record[NPFileNameKey] = filename;
        
        record[NPLocalDocURLKey] = localDocURL;
        NSURL *w = [localDocURL URLByAppendingPathComponent:NPDocumentMetadataDotPlist];
        record[NPLocalDocumentMetadataPlistURLKey] = w;
        
        if( nil != cloudDocURL ){
            record[NPCloudDocURLKey] = cloudDocURL;
            
            NSURL *z = [cloudDocURL URLByAppendingPathComponent: NPDocumentMetadataDotPlist];
            record[NPCloudDocumentMetadataPlistURLKey] = z;
            
        }else{
            [record removeObjectForKey: NPCloudDocURLKey];
            [record removeObjectForKey: NPCloudDocumentMetadataPlistURLKey];
       }

        record[NPLocalStoreOptionsKey] = [[self class] localPersistentStoreOptions];
        record[NPCloudStoreOptionsKey] = [[self class] cloudPersistentStoreOptionsForRecord: record];
        
        [self updateTableViewWithRecord: [record copy]];
        
        return record;
    }
    
}
#pragma mark We never delete a document or its record in this app.

-(void)addRowForRecord: (NSDictionary*)record
{
    
    //@synchronized( self.tableView ){
        
        NSString *uuid = record[NPUUIDKey];
        
        NSAssert( [self validUuidString: uuid], @"Bogus uuid");
        
        NSDictionary *exists = [self recordForUuid: uuid];
        //NSAssert( (nil == exists), @"Record already exists.");
        if( exists ) return ;
        
        [self.docRecords addObject: record];
        
        NSUInteger row = [self.docRecords indexOfObject: record];
        NSIndexPath* indexPath =
        [NSIndexPath indexPathForRow:row inSection:0];
        
        NSArray *indexPaths = @[indexPath];
        
        // Now update those rows
        [self.tableView beginUpdates];{
            
            [self.tableView insertRowsAtIndexPaths:indexPaths
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
            
        }[self.tableView endUpdates];
        
        [self.tableView reloadData];
        
    //}
    
}

-(NSString*)uuidFromMetadataItem: (NSMetadataItem*)item
{
    NSString *result = nil;
    
    NSURL *url = [item valueForKey: NSMetadataItemURLKey];
    NSString *last = [url lastPathComponent];
    BOOL isDocMDataPlist = [last isEqualToString: (NSString*)NPDocumentMetadataDotPlist];
    
    if( isDocMDataPlist ){
        
        NSURL *yaddaYaddaName = [url URLByDeletingLastPathComponent];
        NSURL *yaddaYaddaUuid = [yaddaYaddaName URLByDeletingLastPathComponent];
        NSString *test = [yaddaYaddaUuid lastPathComponent];
        
        if( [self validUuidString: test] ){
            result = test;
        }
    }
    return result;
}
-(NSString*)filenameFromMetadataItem: (NSMetadataItem*)item
{
    NSString *result = nil;
    
    NSURL *url = [item valueForKey: NSMetadataItemURLKey];
    NSString *last = [url lastPathComponent];
    BOOL isDocMDataPlist = [last isEqualToString: (NSString*)NPDocumentMetadataDotPlist];
    
    if( isDocMDataPlist ){
        
        NSURL *yaddaYaddaName = [url URLByDeletingLastPathComponent];
        result = [yaddaYaddaName lastPathComponent];
        
    }
    return result;
}

-(NSDictionary*)enrollMetadataItem: (NSMetadataItem*)metadataItem
{
    NSURL *metadataURL = [metadataItem valueForAttribute: NSMetadataItemURLKey];
    
    NSURL *dirURL = [metadataURL URLByDeletingLastPathComponent];
    [[self class] assureDirectoryURLExists: dirURL];
    
    
    NSString *uuid = [self uuidFromMetadataItem: metadataItem];
    NSDictionary *existingRecord = [self recordForUuid: uuid];
    
    if( nil == existingRecord ){
        
        NSString *filename = [self filenameFromMetadataItem: metadataItem];
        
        NSMutableDictionary *newRecord =
        [self recordEnrolledForFilename: filename
                                   uuid: uuid].mutableCopy;
        
        // This should be the ONLY place where the NPMetadataItemKey is used to write to a document's record.
        // The records of documents discovered by query have this entry;
        // records of documents instantiated in the sandbox do not.
        newRecord[NPMetadataItemKey] = metadataItem;
        // See:
        // [1] -establishDocument:successCallback:failCallback:
        //      where the absence of this entry determines the necessity to
        //      initialize the document's graph of objects.
        // [2] -checkPriorKnowledgeAgainstDiscoveredMetadataForDocument:
        //      which checks a record's metadata (its value for NPMetadataItemKey)
        //      against its document's persistent store options.
        
        NSDictionary *metadataDictionary =
        [NSDictionary dictionaryWithContentsOfURL: metadataURL];
        
        newRecord[NPMetadataDictionaryKey] = metadataDictionary;
        
        NSURL *cloudDocURL = newRecord[NPCloudDocURLKey];
        [self.fileManager startDownloadingUbiquitousItemAtURL:cloudDocURL
                                                        error: nil];
        
        [self updateTableViewWithRecord: newRecord.copy];
        
        return newRecord;
    }else{
        return existingRecord;
    }
}

-(NSDictionary*)recordForDocument: (UIManagedDocument*)document
{
    NSURL *docURL = [document fileURL];
    NSURL *uuidDir = [docURL URLByDeletingLastPathComponent];
    NSString *uuid = [uuidDir lastPathComponent];
    
    NSDictionary *record = [self recordForUuid: uuid];

    return record;
}
-(void)updateTableViewWithRecord: (NSDictionary*)newRecord
{
    NSString *uuid = newRecord[NPUUIDKey];
    NSAssert( (nil != uuid), @"Bogus record");
    
    NSDictionary *existingRecord = [self recordForUuid: uuid];
    
    @synchronized( self.docRecords ){
        
        
        if( nil == existingRecord ){
            
            // Make a new record:
            [(self.docRecords) addObject: newRecord.copy];
             
        }else{
            
            // Replace the existing record:
            NSUInteger existingRecordRow = [(self.docRecords) indexOfObject: existingRecord];
            
            ((self.docRecords))[existingRecordRow] = newRecord;
           
        }
    }
    
    [(self.tableView) reloadData];
    [(self.tableView) setNeedsDisplay];
    
    [self resetTableViewSnoozeAlarm];

}

#pragma mark Model Operations

-(void)addModelVersionToDocument: (UIManagedDocument*)document
{
    
    NSLog(@"Creating a new model version");
    
    NSManagedObjectContext* moc =
    document.managedObjectContext;
        
    ModelVersion* result =
    [NSEntityDescription insertNewObjectForEntityForName:@"ModelVersion"
                                  inManagedObjectContext:moc];
    
    result.versionNumber = [ModelVersion currentVersionNumber];
    
    return;
}
-(void)addTextEntryToDocument: (UIManagedDocument*)document
{
    
    NSLog(@"Creating a new text entry");
    
    NSManagedObjectContext* moc =
    document.managedObjectContext;
    
    // [1] Insert a new TextEntry:
    
    TextEntry* result =
    [NSEntityDescription insertNewObjectForEntityForName:@"TextEntry"
                                  inManagedObjectContext:moc];
    
    // [2] Modify the new TextEntry:
    
    result.modified = [NSDate date];
    
    NSMutableString *temp =
    [NSMutableString stringWithFormat:
     @"-[%@ createTextEntry]",
     NSStringFromClass([self class])];
    
    UIDevice *device = [UIDevice currentDevice];
    [temp appendFormat:@"\n%@ (%@)",
     device.name,
     device.model];
    
    result.text = temp;
    
}

-(void)addObjectGraphToDocument: (UIManagedDocument*)document
{
    NSManagedObjectContext* moc =
    document.managedObjectContext;
    [moc performBlockAndWait: ^() {
        
        [self addTextEntryToDocument: document];
        [self addModelVersionToDocument: document];
                
    }];
    
    [document updateChangeCount: UIDocumentChangeDone];
}

#pragma mark IBActions:

- (IBAction)addDocument:(id)sender
{
    
    // Create a blank document and save it to the local sandbox
    NSUInteger index = [self calculateNextFileNameIndex];
    NSString* fileName = [NSString stringWithFormat:@"%@%lu",
                          BaseFileName,
                          (unsigned long)index];
    
    NSString *uuid = [[NSUUID UUID] UUIDString];
    
    NSMutableDictionary *record =
    [self recordEnrolledForFilename: fileName
                               uuid: uuid];
    
    [self addDocumentFromRecord: record];
    
}
#pragma mark Add Document Programmatically
-(NSInvocation*)callbackForSelector: (SEL)selector
                           document: (UIManagedDocument*)document
{
    NSMethodSignature *sig =
    [[self class] instanceMethodSignatureForSelector: selector];
    
    NSInvocation *inv =
    [NSInvocation invocationWithMethodSignature: sig];
    [inv setSelector: selector];
    [inv retainArguments];
    
    [inv setTarget: self];
    [inv setArgument: (&document)
             atIndex:2];
    return inv;
}

-(void)addDocumentFromRecord: (NSDictionary*)record
{
    self.addButton.enabled = NO;
    [[self.addButton customView ] setNeedsDisplay];
    
    [self addRowForRecord: record];
    
    UIManagedDocument *document = [self instantiateDocumentFromRecord: record];
    
    NSMutableDictionary *updatedRecord = record.mutableCopy;{
        updatedRecord[NPDocumentKey] = document;
        
        NSInvocation *successCallback =
        [self callbackForSelector: @selector(didOpenDocument:)
                         document: document];
        updatedRecord[NPSuccessCallbackKey] = successCallback;
        
        NSInvocation *failCallback =
        [self callbackForSelector: @selector(didFailToOpenDocument:)
                         document: document];
        updatedRecord[NPFailureCallbackKey] = failCallback;
        
        
    }[self updateTableViewWithRecord: updatedRecord];
    
    
    [self resetTableViewSnoozeAlarm];
    
    
    [self establishDocument: document];
    
}

/**
 This method delays the call to -actuallyReloadTableView:until 1.0 second after the most recent call to -resetTableViewSnoozeAlarm.
 
 Suppose we get a burst of calls to -resetTableViewSnoozeAlarm over a short period,
 but each within 1.0 second of the previous. The burst ends when 1.0 second elapses with no call to -resetTableViewSnoozeAlarm.
 
 When the burst ends, the timer, m_tableViewSnoozeAlarm, finally invokes -actuallyReloadTableView:.
 
 */
-(void)resetTableViewSnoozeAlarm
{

    /*
     "-[NSTimer invalidate] Stops the receiver from ever firing again and requests its removal from its run loop."
     */
    [m_tableViewSnoozeAlarm invalidate];
    m_tableViewSnoozeAlarm = nil;
    
    NSRunLoop *main = [NSRunLoop mainRunLoop];
    
    m_tableViewSnoozeAlarm =
    [NSTimer timerWithTimeInterval: 1.0
                            target: self
                          selector: @selector(actuallyReloadTableView:)
                          userInfo: nil
                           repeats: NO];
    
    [main addTimer: m_tableViewSnoozeAlarm
           forMode: NSDefaultRunLoopMode];
    
}

-(void)actuallyReloadTableView: (NSTimer*)timer
{
    NSLog(@"%@: -actuallyReloadTableView: ",
          [[UIDevice currentDevice] model] );
    
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    NSRunLoop *mainRunLoop = [NSRunLoop mainRunLoop];
    NSAssert( (mainRunLoop == runLoop), @"Not main run loop.");
    
    [timer invalidate];
    [m_tableViewSnoozeAlarm invalidate];
    m_tableViewSnoozeAlarm  = nil;
    
    [(self.tableView) reloadData];
    [(self.tableView) setNeedsDisplay];
}

#pragma mark addDocumentFromRecord:documentExists: callbacks:

/*
 When creating or opening a document, I disable the [+] button until the document opens.
 I did this to prevent myself from activating [+] multiple times.
 There's considerable delay in the UI.
 This supporting logic expects only one document to be opening or creating at any one time.
 */
-(void)restoreAddButton
{
    
    // Perturb the view in the main thread:
    dispatch_async(dispatch_get_main_queue(), ^{
        self.addButton.enabled = YES;
        [self resetTableViewSnoozeAlarm];
    });
    
}

-(void)didAddDocument: (UIManagedDocument*)document
{
    [self restoreAddButton];
    
}

-(void)didFailToAddDocument: (UIManagedDocument*)document
{
    [self restoreAddButton];
}

-(void)didOpenDocument: (UIManagedDocument*)document
{
    [self restoreAddButton];
}

-(void)didFailToOpenDocument: (UIManagedDocument*)document
{
    [self restoreAddButton];
}



#pragma mark Utility methods:


-(BOOL)validUuidString: (NSString*)testUuidString
{
    NSUUID *test = [[NSUUID alloc] initWithUUIDString: testUuidString];
     return (nil != test);
}


NSString *NPCopyCloudContainerOnSequeKey = @"copyCloudContainerOnSeque";

#pragma mark - Segue
- (void)prepareForSegue:(UIStoryboardSegue *)segue
                 sender:(id)sender {
    
    if ([segue.identifier isEqualToString:@"Open File Segue"]) {
        
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults synchronize];
        
        BOOL copyContainer = [userDefaults boolForKey:NPCopyCloudContainerOnSequeKey];
        
        NSLog(@"%@ = %@",
              NPCopyCloudContainerOnSequeKey,
              copyContainer ? @"YES" : @"NO" );
        
        if( copyContainer ) {
            // copy the cloud container to the sandbox:
            [[self class] copyCloudContainerToSandbox];
        }
        
        // Find the payload:
        NSIndexPath *indexPath = [self.tableView indexPathForCell: sender];
        NSMutableDictionary *record = (self.docRecords)[indexPath.row];
        
        // Deliver the payload:
        DetailViewController* destination =
        segue.destinationViewController;
        destination.record = record;
        

    }else{
         NSLog( @"Bogus segue.");
    }
    
}

@end
