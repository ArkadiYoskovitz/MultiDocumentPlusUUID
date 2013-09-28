//
//  DocumentsListController.m
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

#import "DocumentsListController+Making.h"
#import "DocumentsListController+Querying.h"
#import "DocumentsListController+Resources.h"

#import "DetailViewController.h"
#import "DocumentCell.h"
#import <CoreData/CoreData.h>

#import "ModelVersion.h"

#import "TextEntry.h"

#import "NSURL+NPAssisting.h"

#import "UIDocument+NPExtending.h"



static NSString* const BaseFileName = @"TestDoc";


const NSString* NPLocalDocURLKey     = @"Local Document URL";
const NSString* NPCloudDocURLKey     = @"Cloud Document URL";
const NSString* NPCloudLogFilesURLKey     = @"Cloud Log Files URL";
const NSString* NPUUIDKey         = @"UUID";
const NSString* NPStoreOptionsKey = @"Persistent Store Options dictionary";


const NSString* NPMetadataItemKey = @"NSMetadataItem";
const NSString* NPMetadataDictionaryKey     = @"Metadata from Query Result Item";

const NSString* NPFileNameKey     = @"File Name";

const NSString* NPDocumentKey     = @"Document";

@interface DocumentsListController()        

- (NSUInteger)calculateNextFileNameIndex;
@end

@implementation DocumentsListController

@synthesize addButton;
@dynamic docRecords;

@dynamic notificationObservers;


#pragma mark Property Accessors:

-(NSFileManager*)fileManager
{
    return [[self class] fileManager];
}
-(NSMutableOrderedSet*)docRecords
{
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
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if ([[self class] isCloudEnabled]) {
        [self launchMetadataQuery];
    } else {
        [self discoverLocalDocs];
    }
    
    
    [self observeWillTerminate];
}
-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [(self.tableView) reloadData];
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
                 @"document state = %d",
                 state );
        
        NSString *path = [document fileURL].path;
        [document closeWithCompletionHandler: ^(BOOL success) {
            if( success ){
                NSLog(@"closed %@", path);
            }else{
                NSLog(@"failed to close properly: %@", path);
                NSLog(@"state = %d",
                      document.documentState);
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

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    
    // Return the number of entries in our weight history
    return [self.docRecords count];
}

-(void)saveConfigureCell:(DocumentCell *)cell
                 row: (NSUInteger)row
{
    cell.fileNameUILabel.text = @"--";
    
    NSMutableDictionary *record = (self.docRecords)[row];
    
    //    UIManagedDocument *document = [record objectForKey: NPDocumentKey];
    //    NSAssert( (nil != document), @"Bogus cell, no document");
    
    NSString* fileName = record[NPFileNameKey];
    NSMutableString *tmp = fileName.mutableCopy;
    
    UIManagedDocument *doc = record[NPDocumentKey];
    NSURL *localDocURL = [doc fileURL];
    
    NSNumber *isUploaded   = @NO;
    [localDocURL getResourceValue: &isUploaded
                           forKey: NSURLUbiquitousItemIsUploadedKey // NSMetadataUbiquitousItemIsUploadedKey //
                            error: nil];
    
    NSNumber *isDownloaded = @NO;
    [localDocURL getResourceValue: &isDownloaded
                           forKey: NSURLUbiquitousItemIsDownloadedKey  //NSMetadataUbiquitousItemIsDownloadedKey
                            error: nil];
    
    NSString *percentUploaded   = @"??";
    NSString *percentDownloaded = @"??";
   
    if(nil == doc){
        [tmp appendString: @" (nil)"];
    }else{
        [tmp appendFormat: @", %@", [doc npDocumentStateAsString]];
        
        NSMetadataItem *mdItem = record[NPMetadataItemKey];
        
        if( nil != mdItem ){
            
            id v = [mdItem valueForAttribute:NSMetadataUbiquitousItemPercentDownloadedKey];
            
            if( [(NSObject*)v isKindOfClass:[NSNumber class]] ){
                
                NSNumber *percentDn = (NSNumber *)v;
                
                percentDownloaded = [[percentDn stringValue] copy];
                
                if( [percentDn unsignedIntegerValue] < 100 ){
                    
                    // Somewhat hackish...
                    [self.tableView performSelector: @selector(reloadData)
                                         withObject: nil
                                         afterDelay: 0.5
                                            inModes: @[NSRunLoopCommonModes, NSDefaultRunLoopMode] ];
                    
                }
            }
            
            v = [mdItem valueForAttribute:NSMetadataUbiquitousItemPercentUploadedKey];
            
            if( [(NSObject*)v isKindOfClass:[NSNumber class]] ){
                
                NSNumber *percentUp = (NSNumber *)v;
                
                percentUploaded = [[percentUp stringValue] copy];
                
                if( [percentUp unsignedIntegerValue] < 100 ){
                    
                    // Somewhat hackish...
                    [self.tableView performSelector: @selector(reloadData)
                                         withObject: nil
                                         afterDelay: 0.5
                                            inModes: @[NSRunLoopCommonModes, NSDefaultRunLoopMode] ];
                    
                }
            }

        } //if( nil != mdItem )
    }
    
    [tmp appendFormat: @" up: %@ (%@), dn: %@ (%@)",
     [isUploaded boolValue] ? @"+" : @"-",
     percentUploaded,
     [isDownloaded boolValue] ? @"+" : @"-",
     percentDownloaded];
    
    
    cell.fileNameUILabel.text = tmp;
    
    /*
     {
     // debug passage
     NSMutableString *msg = [NSMutableString stringWithFormat: @"\n\nCell for row: %d\n", row];
     [msg appendFormat: @"doc.localizedName = %@\n", doc.localizedName];
     [msg appendFormat: @"uuid = %@\n", record[NPUUIDKey] ];
     [msg appendFormat: @"cell.fileNameUILabel.text = %@", cell.fileNameUILabel.text ];
     [msg appendString: @"\n\n"];
     
     NSLog(@"%@", msg);
     }
     */
    
    cell.userInteractionEnabled = [doc isKindOfClass: [UIManagedDocument class]];
}
-(void)configureCell: (DocumentCell *)cell
                 row: (NSUInteger)row
{
    cell.fileNameUILabel.text = @"--";
    
    NSMutableDictionary *record = (self.docRecords)[row];
        
    NSString* fileName = record[NPFileNameKey];
    NSMutableString *tmp = fileName.mutableCopy;
    
    UIManagedDocument *doc = record[NPDocumentKey];
    NSURL *localDocURL = [doc fileURL];
    
    NSNumber *isUploaded   = @NO;
    [localDocURL getResourceValue: &isUploaded
                           forKey: NSURLUbiquitousItemIsUploadedKey // NSMetadataUbiquitousItemIsUploadedKey //
                            error: nil];
    
    NSNumber *isDownloaded = @NO;
    [localDocURL getResourceValue: &isDownloaded
                           forKey: NSURLUbiquitousItemIsDownloadedKey  //NSMetadataUbiquitousItemIsDownloadedKey
                            error: nil];
    
    NSString *percentTransferred   = @"??";
    
    if(nil == doc){
        [tmp appendString: @" <nil> "];
    }else{
        [tmp appendFormat: @", %@", [doc npDocumentStateAsString]];
        
        NSMetadataItem *mdItem = record[NPMetadataItemKey];
        BOOL thisDeviceIsSource = (nil == mdItem);
        
        BOOL success = NO;
        
        if( thisDeviceIsSource ){
            
            NSNumber *percentUp = nil;
            success = [localDocURL getResourceValue:&percentUp
                                             forKey:NSURLUbiquitousItemIsUploadedKey
                                              error:nil];
            
            if( success ){
                
                
                percentTransferred = [[percentUp stringValue] copy];
                
                if( [percentUp unsignedIntegerValue] < 100 ){
                    
                    // Somewhat hackish...
                    [self.tableView performSelector: @selector(reloadData)
                                         withObject: nil
                                         afterDelay: 0.5
                                            inModes: @[NSRunLoopCommonModes, NSDefaultRunLoopMode] ];
                    
                }
                
                [tmp appendFormat: @" Up: %@ %c",
                 percentTransferred, '%'];
            }
        }else{
            NSNumber *percentDn = nil;
            BOOL success = [localDocURL getResourceValue:&percentDn
                                                  forKey:NSURLUbiquitousItemIsDownloadedKey
                                                   error:nil];
            
            if( success ){
                
                
                percentTransferred = [[percentDn stringValue] copy];
                
                if( [percentDn unsignedIntegerValue] < 100 ){
                    
                    // Somewhat hackish...
                    [self.tableView performSelector: @selector(reloadData)
                                         withObject: nil
                                         afterDelay: 0.5
                                            inModes: @[NSRunLoopCommonModes, NSDefaultRunLoopMode] ];
                    
                }
                
                [tmp appendFormat: @" Dn: %@ %c",
                 percentTransferred, '%'];
            }
            
            
        } //if( nil != mdItem )
    }
    
    cell.fileNameUILabel.text = tmp;
    
    cell.userInteractionEnabled = [doc isKindOfClass: [UIManagedDocument class]];
}

- (void)tableView:(UITableView *)tableView
  willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    NSMutableDictionary *record = (self.docRecords)[indexPath.row];
    UIManagedDocument *doc = record[NPDocumentKey];
    
    if([doc isKindOfClass:[UIManagedDocument class]]){
        cell.backgroundColor = [UIColor whiteColor];
    }else{
        cell.backgroundColor = [UIColor lightGrayColor];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static const NSString *CellIdentifier = @"Document Cell";
    
    DocumentCell *cell = 
    [tableView dequeueReusableCellWithIdentifier: (NSString *)CellIdentifier];
    
    [self configureCell: cell
                    row: indexPath.row];
    
    return cell;
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
-(NSMutableDictionary*)mapUuidsToRecords
{
    NSMutableDictionary *map =
    [NSMutableDictionary dictionaryWithCapacity: self.docRecords.count];
    
    for( NSDictionary *d in self.docRecords ){
        // local document records have no metadata.
        
        NSString *uuid = d[NPUUIDKey];
        map[uuid] = d;
    }
    return map;
}

-(NSMutableDictionary*)recordForUuid: (NSString*)uuid
{
    NSMutableDictionary *map = [self mapUuidsToRecords];
    return  map[uuid];
}

-(void)addRowForRecord: (NSMutableDictionary*)record
{
    
    @synchronized( self ){
        
        NSString *uuid = record[NPUUIDKey];
        
        NSAssert( [self validUuidString: uuid], @"Bogus uuid");
        
        NSMutableDictionary *exists = [self recordForUuid: uuid];
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

    }

}

-(NSMutableDictionary*)recordEnrolledForFilename: (NSString*)filename
                                            uuid: (NSString*)uuid
{
    /*
     This method retrieves a record for a uuid, 
     or builds and stores an appropriate record for the uuid is no such record exists.
     
     Note that the MultiDocument app only adds documents;
     it never removes any.
     
     */
    
    NSAssert( [self validUuidString: uuid], @"Bogus uuid: %@", uuid);
    NSAssert( (0 != filename.length), @"Bogus filename, empty");
    
    NSURL *localDocURL = [[self class] localDocURLForFileName: filename
                                                         uuid: uuid];
    NSURL *cloudDocURL = [[self class] cloudDocURLForFileName: filename
                                                         uuid: uuid];
    
    NSURL *uuidDir = [[localDocURL URLByDeletingLastPathComponent] absoluteURL];
    BOOL ok = [[self class] assureDirectoryURLExists: uuidDir];
    NSAssert( ok, @"Can't make directory: %@", [uuidDir absoluteString] );
    
    
    NSMutableDictionary *existing = [self recordForUuid: uuid];
    
    
    if( nil != existing ){
        BOOL sanity = [filename isEqualToString: existing[NPFileNameKey]];
        
        NSAssert( sanity, @"Conflict: filenames %@ & %@ for uuid: %@",
                 filename,
                 existing[NPFileNameKey],
                 uuid);
        return existing;
        
    }else{
        NSMutableDictionary *record = nil;
        
        @synchronized(self){
            
            record = [NSMutableDictionary dictionaryWithCapacity: 8];
            
            record[NPUUIDKey] = uuid;
            record[NPFileNameKey] = filename;
            
            record[NPLocalDocURLKey] = localDocURL;
            
            if( nil != cloudDocURL ){
                record[NPCloudDocURLKey] = cloudDocURL;
            }else{
                [record removeObjectForKey: NPCloudDocURLKey];
            }
            
            NSDictionary *storeOptions = [[self class] persistentStoreOptionsForDocumentFileURL: localDocURL];
            
            record[NPStoreOptionsKey] = storeOptions;
            
        }

        return record;
    }
    
}

const NSString *NPDocMDataDotPlistKey = @"DocumentMetadata.plist";

-(NSString*)uuidFromMetadataItem: (NSMetadataItem*)item
{
    NSString *result = nil;
    
    NSURL *url = [item valueForKey: NSMetadataItemURLKey];
    NSString *last = [url lastPathComponent];
    BOOL isDocMDataPlist = [last isEqualToString: (NSString*)NPDocMDataDotPlistKey];
    
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
    BOOL isDocMDataPlist = [last isEqualToString: (NSString*)NPDocMDataDotPlistKey];
    
    if( isDocMDataPlist ){
        
        NSURL *yaddaYaddaName = [url URLByDeletingLastPathComponent];
        result = [yaddaYaddaName lastPathComponent];
        
    }
    return result;
}

-(NSMutableDictionary*)enrollMetadataItem: (NSMetadataItem*)metadataItem
{
    NSURL *metadataURL = [metadataItem valueForAttribute: NSMetadataItemURLKey];
    
    NSURL *dirURL = [metadataURL URLByDeletingLastPathComponent];
    [[self class] assureDirectoryURLExists: dirURL];
    
    
    NSString *uuid = [self uuidFromMetadataItem: metadataItem];
    NSMutableDictionary *record = [self recordForUuid: uuid];
    
    if( nil == record ){
        
        NSString *filename = [self filenameFromMetadataItem: metadataItem];
        
        // -enrollFilename:uuid adds a row to the table view.
        record = [self recordEnrolledForFilename: filename
                                            uuid: uuid];
        
        // This should be the ONLY place where the NPMetadataItemKey is used to write to a document's record.
        // The records of documents discovered by query have this entry;
        // records of documents instantiated in the sandbox do not.
        record[NPMetadataItemKey] = metadataItem;
        // See:
        // [1] -establishDocument:successCallback:failCallback:
        //      where the absence of this entry determines the necessity to
        //      initialize the document's graph of objects.
        // [2] -checkPriorKnowledgeAgainstDiscoveredMetadataForDocument:
        //      which checks a record's metadata (its value for NPMetadataItemKey)
        //      against its document's persistent store options.
        
        NSDictionary *metadataDictionary =
        [NSDictionary dictionaryWithContentsOfURL: metadataURL];
        
        record[NPMetadataDictionaryKey] = metadataDictionary;
        
        NSURL *cloudDocURL = record[NPCloudDocURLKey];
        [self.fileManager startDownloadingUbiquitousItemAtURL:cloudDocURL
                                                        error: nil];
    }
    
    return record;
}

-(NSMutableDictionary*)recordForDocument: (UIManagedDocument*)document
{
    NSURL *docURL = [document fileURL];
    NSURL *uuidDir = [docURL URLByDeletingLastPathComponent];
    NSString *uuid = [uuidDir lastPathComponent];
    
    NSMutableDictionary *record = [self recordForUuid: uuid];

    return record;
}

#pragma mark Model Operations 

-(void)addModelVersionToDocument: (UIManagedDocument*)document
{
    
    NSLog(@"Creating a new model version");
    
    NSManagedObjectContext* moc =
    document.managedObjectContext;
    
//    NSEntityDescription* desc =
//    [NSEntityDescription entityForName:@"ModelVersion"
//                inManagedObjectContext:moc];
//    
//    ModelVersion* result = [[ModelVersion alloc]
//                            initWithEntity:desc
//                            insertIntoManagedObjectContext:moc];
    
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
    
//    NSEntityDescription* desc =
//    [NSEntityDescription entityForName:@"TextEntry"
//                inManagedObjectContext:moc];
    
    // [1] Insert a new TextEntry:
//    TextEntry* result = [[TextEntry alloc]
//                         initWithEntity:desc
//                         insertIntoManagedObjectContext:moc];
    
    
    TextEntry* result =
    [NSEntityDescription insertNewObjectForEntityForName:@"TextEntry"
                                  inManagedObjectContext:moc];
    
    // [2] Modify the new TextEntry:
    // At this point (early in its life cycle),
    // the document returns nil for its localizedName.
    // result.title = document.localizedName; // yields nil
    // Use the record instead:

    NSMutableDictionary *record = [self recordForDocument: document];
    result.title = record[NPFileNameKey];
    
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

- (IBAction)addDocument:(id)sender {
    
    // Create a blank document and save it to the local sandbox
    NSUInteger index = [self calculateNextFileNameIndex];
    NSString* fileName = [NSString stringWithFormat:@"%@%d",
                         BaseFileName,
                         index];
        
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

-(void)addDocumentFromRecord: (NSMutableDictionary*)record
{
    self.addButton.enabled = NO;
    
    [self addRowForRecord: record];
    
    UIManagedDocument *document = [self instantiateDocumentFromRecord: record];
    record[NPDocumentKey] = document;

    NSInvocation *successCallback = nil;
    NSInvocation *failCallback = nil;
    
    successCallback = [self callbackForSelector: @selector(didOpenDocument:)
                                       document: document];
    failCallback    = [self callbackForSelector: @selector(didFailToOpenDocument:)
                                       document: document];
    
    [(self.tableView) reloadData];

    [self establishDocument: document
            successCallback: successCallback
               failCallback: failCallback];
}
#pragma mark addDocumentFromRecord:documentExists: callbacks:

-(void)didAddDocument: (UIManagedDocument*)document
{
    /*
      When creating or opening a document, I disable the [+] button until the document opens. 
     I did this to prevent myself from activating [+] multiple times.
     There's considerable delay in the UI.
     This supporting logic expects only one document to be opening or creating at any one time.
     */
    self.addButton.enabled = YES;

    [self.tableView reloadData];
}

-(void)didFailToAddDocument: (UIManagedDocument*)document
{
    self.addButton.enabled = YES;
    
    [self.tableView reloadData];
}

-(void)didOpenDocument: (UIManagedDocument*)document
{
    self.addButton.enabled = YES;
    
    [self.tableView reloadData];
}

-(void)didFailToOpenDocument: (UIManagedDocument*)document
{
    self.addButton.enabled = YES;
    
    [self.tableView reloadData];
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
        
        // Afterthought: check for sanity:
        DocumentCell* cell = sender;
        NSString* fileName = cell.fileNameUILabel.text;
        NSAssert( [fileName hasPrefix: record[NPFileNameKey]],
                 @"Bogus cell file name or index");

        // Deliver the payload:
        DetailViewController* destination =
        segue.destinationViewController;
        destination.record = record;
        

    }else{
         NSLog( @"Bogus segue.");
    }
    
}

@end
