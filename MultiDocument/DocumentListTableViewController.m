//
//  MDCDMasterViewController.m
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

#import "DocumentListTableViewController+Making.h"
#import "DocumentListTableViewController+Querying.h"
#import "DocumentListTableViewController+Resources.h"

#import "DocumentViewController.h"
#import "DocumentCell.h"
#import <CoreData/CoreData.h>

#import "ModelVersion.h"

#import "TextEntry.h"

#import "NSURL+NPAssisting.h"


static NSString* const BaseFileName = @"TestDoc";


const NSString* NPLocalURLKey     = @"Local URL";
const NSString* NPCloudURLKey     = @"Cloud URL";
const NSString* NPUUIDKey         = @"UUID";
const NSString* NPStoreOptionsKey = @"Persistent Store Options dictionary";


const NSString* NPMetadataItemKey = @"NSMetadataItem";
const NSString* NPMetadataDictionaryKey     = @"Metadata from Query Result Item";

const NSString* NPFileNameKey     = @"File Name";

const NSString* NPDocumentKey     = @"Document";

@interface DocumentListTableViewController()        

- (NSUInteger)calculateNextFileIndex;
@end

@implementation DocumentListTableViewController
//@dynamic listOfFiles;
//@dynamic localURLsForFileNames;
//@dynamic localDocsForFileNames;
//@dynamic localURLsForUUIDs;

@synthesize addButton;
//@dynamic fileManager;
@dynamic docRecords;
@dynamic notifications;

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
-(NSMutableArray*)notifications
{
    if( nil == m_notifications ){
        m_notifications = [[NSMutableArray alloc] initWithCapacity: 8];
    }
    return m_notifications;
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
    
    [self.notifications addObject: observer];

}
- (void)viewDidLoad
{
    [super viewDidLoad];
    //[self clearCloudContainer];
                
    if ([[self class] isCloudEnabled]) {
        [self launchMetadataQuery];
    } else {
        [self discoverLocalDocs];
    }
    
    [self observeWillTerminate];
}
-(void)closeDocuments
{
    for( NSDictionary *record in self.docRecords ){
        
        UIManagedDocument *document = [record objectForKey: NPDocumentKey];
        
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


- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Document Cell";
    
    DocumentCell *cell = 
    [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    NSMutableDictionary *record = [self.docRecords objectAtIndex: indexPath.row];
    
//    UIManagedDocument *document = [record objectForKey: NPDocumentKey];
//    NSAssert( (nil != document), @"Bogus cell, no document");
    
    NSString* fileName = [record objectForKey: NPFileNameKey];
    
    cell.fileNameUILabel.text = fileName;
    
    UIManagedDocument *doc = [record objectForKey: NPDocumentKey];
    UIDocumentState state = doc.documentState;
    
    if( (nil != doc) && (UIDocumentStateNormal == state) ){
        cell.backgroundColor = [UIColor whiteColor];
    }else{
        cell.backgroundColor = [UIColor lightGrayColor];
    }
        
    return cell;
}


#pragma mark - Helper

- (NSUInteger)calculateNextFileIndex {
    
    NSUInteger max = 0;
  
    for (NSDictionary* nextRecord in self.docRecords) {
        
        NSString *name = [nextRecord objectForKey: NPFileNameKey];
        
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
        
        NSString *uuid = [d objectForKey: NPUUIDKey];
        [map setObject: d
                forKey: uuid];
    }
    return map;
}

-(NSMutableDictionary*)recordForUuid: (NSString*)uuid
{
    NSMutableDictionary *map = [self mapUuidsToRecords];
    return  [map objectForKey: uuid];
}

-(void)addRowForRecord: (NSMutableDictionary*)record
{
    
    @synchronized( self ){
        
        NSString *uuid = [record objectForKey: NPUUIDKey];
        
        NSAssert( [self validUuidString: uuid], @"Bogus uuid");
        
        NSMutableDictionary *exists = [self recordForUuid: uuid];
        //NSAssert( (nil == exists), @"Record already exists.");
        if( exists ) return ;
        
        [self.docRecords addObject: record];
        
        NSUInteger row = [self.docRecords indexOfObject: record];
        NSIndexPath* indexPath =
        [NSIndexPath indexPathForRow:row inSection:0];
        
        NSArray *indexPaths = [NSArray arrayWithObject: indexPath];
        
        // Now update those rows
        [self.tableView beginUpdates];{
            
            [self.tableView insertRowsAtIndexPaths:indexPaths
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
            
        }[self.tableView endUpdates];
        
        [self.tableView reloadData];

    }

}

-(NSMutableDictionary*)enrollFilename: (NSString*)filename
                                 uuid: (NSString*)uuid
{
    /*
     This method instantiates a local/sandbox document.
     
     Note that the MultiDocument app only adds documents;
     it never removes any.
     Therefore, there's an -enrollFilename:uuid: method, but no -deleteFilename:uuid:
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
    NSAssert( (nil == existing), @"Record exists for uuid: %@", uuid);
    
    NSMutableDictionary *record = nil;
    
    @synchronized(self){
        
        record = [NSMutableDictionary dictionaryWithCapacity: 8];
        
        [record setObject: uuid
                   forKey: NPUUIDKey];
        [record setObject: filename
                   forKey: NPFileNameKey];
        
        [record setObject: localDocURL
                   forKey: NPLocalURLKey];
        
        if( nil != cloudDocURL ){
            [record setObject: cloudDocURL
                       forKey: NPCloudURLKey];
        }else{
            [record removeObjectForKey: NPCloudURLKey];
        }
        
        NSDictionary *storeOptions = [[self class] persistentStoreOptionsForDocumentFileURL: localDocURL];
        
        [record setObject: storeOptions
                   forKey: NPStoreOptionsKey];
        
        
    }
    return record;
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
        record = [self enrollFilename: filename
                                 uuid: uuid];
    }
    
    [record setObject: metadataItem
               forKey: NPMetadataItemKey];

    NSDictionary *metadataDictionary =
    [NSDictionary dictionaryWithContentsOfURL: metadataURL];

    [record setObject: metadataDictionary
               forKey: NPMetadataDictionaryKey];
    
    NSURL *cloudDocURL = [record objectForKey: NPCloudURLKey];
    [self.fileManager startDownloadingUbiquitousItemAtURL:cloudDocURL
                                                    error: nil];

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
    
    NSEntityDescription* desc =
    [NSEntityDescription entityForName:@"ModelVersion"
                inManagedObjectContext:moc];
    
    ModelVersion* result = [[ModelVersion alloc]
                            initWithEntity:desc
                            insertIntoManagedObjectContext:moc];
    
    result.versionNumber = [ModelVersion currentVersionNumber];
    
    return;
}
-(void)addTextEntryToDocument: (UIManagedDocument*)document
{
    
    NSLog(@"Creating a new text entry");
    
    NSManagedObjectContext* moc =
    document.managedObjectContext;
    
    NSEntityDescription* desc =
    [NSEntityDescription entityForName:@"TextEntry"
                inManagedObjectContext:moc];
    
    TextEntry* result = [[TextEntry alloc]
                         initWithEntity:desc
                         insertIntoManagedObjectContext:moc];
    
    // At this point, document returns nil for its localizedName.
    // result.title = document.localizedName; // yields nil
    // Use the record instead:
    
    NSMutableDictionary *record = [self recordForDocument: document];
    result.title = [record objectForKey: NPFileNameKey];
    
    result.modified = [NSDate date];
    
    NSMutableString *temp =
    [NSMutableString stringWithString: @"-[DLTVController createTextEntry]"];
    
    UIDevice *device = [UIDevice currentDevice];
    [temp appendFormat:@"\n%@ (%@)",
     device.name,
     device.model];
    
    result.text = [temp copy];
    
}

-(void)addObjectGraphToDocument: (UIManagedDocument*)document
{
    [self addTextEntryToDocument: document];
    [self addModelVersionToDocument: document];
}

#pragma mark IBActions:

- (IBAction)addDocument:(id)sender {
    
    // Create a blank document and save it to the local sandbox
    NSUInteger index = [self calculateNextFileIndex];
    NSString* fileName = [NSString stringWithFormat:@"%@%d",
                         BaseFileName,
                         index];
        
    NSString *uuid = [[NSUUID UUID] UUIDString];
    
    NSMutableDictionary *record =
    [self enrollFilename: fileName
                    uuid: uuid];
        
    [self addDocumentFromRecord: record
                 documentExists: NO];


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
              documentExists: (BOOL)documentExists
{
    self.addButton.enabled = NO;

    UIManagedDocument *document = [[self class] instantiateDocumentFromRecord: record];
    [record setObject: document
               forKey: NPDocumentKey];
    
    [self addRowForRecord: record];
    
    NSInvocation *successCallback = nil;
    NSInvocation *failCallback = nil;
    if( documentExists ){
        successCallback = [self callbackForSelector: @selector(didOpenDocument:)
                                           document: document];
        failCallback    = [self callbackForSelector: @selector(didFailToOpenDocument:)
                                           document: document];
        
        [self establishDocument: document
                successCallback: successCallback
                   failCallback: failCallback];
        
    }else{
        NSInvocation *initializorCallback =
        [self callbackForSelector:@selector(addObjectGraphToDocument:)
                         document:document];
        
        successCallback =
        [self callbackForSelector:@selector(didAddDocument:)
                         document:document];
        
        failCallback =
        [self callbackForSelector:@selector(didFailToAddDocument:)
                         document:document];
        
        [self saveCreatingSaveOverwriting: document
                              initializor:initializorCallback
                          successCallback:successCallback
                             failCallback:failCallback];

    }
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
    
}

-(void)didFailToAddDocument: (UIManagedDocument*)document
{
    self.addButton.enabled = NO;
   
}

-(void)didOpenDocument: (UIManagedDocument*)document
{
    self.addButton.enabled = YES;
    
}

-(void)didFailToOpenDocument: (UIManagedDocument*)document
{
    self.addButton.enabled = NO;
    
}


#pragma mark Utility methods:


-(BOOL)validUuidString: (NSString*)testUuidString
{
    NSUUID *test = [[NSUUID alloc] initWithUUIDString: testUuidString];
     return (nil != test);
}



#pragma mark - Segue
- (void)prepareForSegue:(UIStoryboardSegue *)segue
                 sender:(id)sender {
    
    if ([segue.identifier isEqualToString:@"Open File Segue"]) {
        
        // Find the payload:
        NSIndexPath *indexPath = [self.tableView indexPathForCell: sender];
        NSMutableDictionary *record = [self.docRecords objectAtIndex: indexPath.row];
        
        // Deliver the payload:
        DocumentViewController* destination =
        segue.destinationViewController;
        destination.record = record; 
        
        // Afterthought: check for sanity:
        DocumentCell* cell = sender;
        NSString* fileName = cell.fileNameUILabel.text;
        NSAssert( [fileName isEqualToString: [record objectForKey: NPFileNameKey]],
                 @"Bogus cell file name or index");

    }
}

@end
