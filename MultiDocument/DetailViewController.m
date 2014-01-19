//
//  DetailViewController.m
//  MultiDocumentPlusUUID

//
// MultiDocumentPlusUUID derives from Rich Warren's MultiDocument example.
// See: http://www.freelancemadscience.com/fmslabs_blog/2011/12/19/syncing-multiple-core-data-documents-using-icloud.html
//
//  Modified by Don Briggs on 2013 March 22.
//  Copyright (c) 2013.
//


#import "DetailViewController.h"
#import "DetailViewController+Pinging.h"

#import "DocumentsListController+Resources.h"
#import "DocumentsListController+Making.h"


#import "TextEntry.h"

#import "DocumentsListController.h" // Get the keys for the record

#import "NSURL+NPAssisting.h"

#import "UIDocument+NPExtending.h"

#import "NSDictionary+NPAssisting.h"

@interface DetailViewController()

@property (readonly, strong) NSMutableArray* notificationObservers;
//@property (readwrite, strong) UIManagedDocument *document;

@property (readonly, strong) NSURL *localDocURL;
@property (readonly, strong) NSURL *cloudDocURL;
@property (readonly, strong) NSString *fileName;
@property (readonly, strong) NSDictionary *storeOptions;
@property (readonly, strong) NSString *uuid;
@property (readonly, strong) NSDictionary *metadata;

@property (readwrite, assign) NSUInteger retryCount;

@end

@implementation DetailViewController

//@synthesize documentTitleTextField = _documentTitle;
@synthesize docStateTextField = _docStateTextField;
@synthesize textView = _text;

@dynamic notificationObservers;

@synthesize retryCount;

@dynamic localDocURL;
@dynamic cloudDocURL;
@dynamic fileName;
@dynamic storeOptions;
@dynamic uuid;
@dynamic metadata;

-(UIManagedDocument*)document
{
    return (self.record)[NPDocumentKey];
}


-(NSFileManager*)fileManager
{
    return [DocumentsListController fileManager];
}
#pragma mark Convenience accessors for items stored in self.record
-(NSURL*)localDocURL
{
    return (self.record)[NPLocalDocURLKey];
}
-(NSURL*)cloudDocURL
{
    return (self.record)[NPCloudDocURLKey];
}
-(NSString*)fileName
{
    return (self.record)[NPFileNameKey];
}
-(NSDictionary*)storeOptions
{
    return (self.record)[NPStoreOptionsKey];
}
-(NSString*)uuid
{
    return (self.record)[NPUUIDKey];
}
-(NSDictionary*)metadata
{
    return (self.record)[NPMetadataDictionaryKey];
}

+(NSArray*)fetchResultsSortDescriptors
{
    return @[];
}

-(NSArray*)fetchedObjectsFromMocFetchRequest
{
    NSManagedObjectContext *moc = [self.document managedObjectContext];
    
    // GLITCH: moc has no registered objects.
    // The following call triggers -mocObjectsDidChange:
    
    NSArray __block *result = nil;

    [moc performBlockAndWait:^(){
        NSError *error = nil;
        
        NSFetchRequest *frq = self.fetchRequest;

        result = [moc executeFetchRequest: frq
                                    error: &error];
        
        if( error ){
            NSLog(@"-[NSManagedObjectContext executeFetchRequest:error:] Unresolved error %@, %@",
                  error, [error userInfo]);
            exit(-1);  // Fail
            
        }else{
            NSSet *registeredObjects = [moc registeredObjects];
            NSLog(@" registeredObjects = %@", [registeredObjects description] );

        }
    }];
  
    
    

    return result;
}
+(NSString*)entityName
{
    return @"TextEntry";
}

-(NSFetchRequest*)fetchRequest
{
    
    NSFetchRequest *result = nil;
    NSManagedObjectContext *moc = [self.document managedObjectContext];
    
    NSString *entityName = [[self class] entityName];
    NSEntityDescription *entity = [NSEntityDescription entityForName:entityName
                                              inManagedObjectContext:moc];
    NSArray *sortDescriptors = [[self class] fetchResultsSortDescriptors];
    
    result = [[NSFetchRequest alloc] init];
    [result setEntity:entity];
    [result setSortDescriptors:sortDescriptors];
    
    [result setReturnsObjectsAsFaults: NO];
    [result setShouldRefreshRefetchedObjects: YES];
    
    return result;
}

-(NSArray*)fetchedObjects
{
    NSArray *result = nil;
    
    if( nil == self.document ){
        result = @[];
    }else{
        result = [self fetchedObjectsFromMocFetchRequest];
    }
    
    return result;
}
-(TextEntry*)fetchedTextEntry
{
    TextEntry *result = nil;
    NSArray *fObjs = [self fetchedObjects];
    
    switch ( fObjs.count ) {
        case 0:
        {
            break;
        }
        case 1:
        {
            result = [fObjs lastObject];
            break;
        }
        default:
        {
            NSAssert( NO, @"Bogus count of fetched objects = %d", fObjs.count);
            break;
        }
    }
    return result;
}
-(NSMutableArray*)notificationObservers
{
    if( nil == m_notificationObservers ){
        m_notificationObservers = [[NSMutableArray alloc] initWithCapacity: 4];
    }
    return m_notificationObservers;
}

-(void)resetMocAndParent
{
    /** Triggers:
        NSManagedObjectContextObjectsDidChangeNotification, 
     which triggers:
        [self readModelWriteView]
     
     */
    
    NSManagedObjectContext *moc = self.document.managedObjectContext;
    if(nil == moc) return;
    
    [moc performBlockAndWait:^(){
    
        [moc reset];
        
        NSManagedObjectContext *parent = [moc parentContext];
        [parent performBlockAndWait:^(){
            [parent reset];
        }];
    
    }];
}

-(void)observeDocument
{
    NSNotificationCenter* center =
    [NSNotificationCenter defaultCenter];
    
    NSPersistentStoreCoordinator *psc =
    self.document.managedObjectContext.persistentStoreCoordinator;
    NSAssert( (nil !=psc),
             @"-[%@ observeDocument] found nil psc",
             NSStringFromClass([self class]));
    
    id observer =
    [center addObserverForName:NSPersistentStoreDidImportUbiquitousContentChangesNotification
                        object:psc
                         queue:nil
                    usingBlock:^(NSNotification *note) {
                        
                        [self logLatency];
                        
                        NSString *currentDeviceModel = [[UIDevice currentDevice] model];
                        
                        NSLog(@"%@: NSPersistentStoreDidImportUbiquitousContentChangesNotification: Merging changes",
                              currentDeviceModel );
                                                
                        NSManagedObjectContext* moc =
                        self.document.managedObjectContext;
                        
                        [moc performBlockAndWait: ^() {
                            
                            NSUndoManager * undoManager = [moc undoManager];
                            [undoManager disableUndoRegistration];{
                                [moc mergeChangesFromContextDidSaveNotification:note];
                                [moc processPendingChanges];
                            }[undoManager enableUndoRegistration];
                            
                        }];
                        
                        [self readModelWriteView];
                        [self snoozeToPingAfterMostRecentUbiquitousContentChange];

                    }];
    [self.notificationObservers addObject:observer];
    
    observer =
    [center addObserverForName:UIDocumentStateChangedNotification
                        object:self.document
                         queue:nil
                    usingBlock:^(NSNotification *note) {
                        
                        UIDocumentState state = self.document.documentState;
                        
                        NSLog(@"%@: UIDocumentStateChangedNotification:",
                              [[UIDevice currentDevice] model]);
                        
                        NSString *docStateText = [self.document npDocumentStateAsString];
                        NSLog(@"    new state: %@", docStateText);
                        
                        if (state == UIDocumentStateNormal) {
                            self.retryCount = 0;
                            NSLog(@"    self.retryCount = 0 ");
                        }else{
                            self.textView.backgroundColor = [UIColor lightGrayColor];
                        }

                        [self readModelWriteView];

                    }];
    [self.notificationObservers addObject:observer];
    
    observer =
    [center addObserverForName:NSManagedObjectContextObjectsDidChangeNotification
                        object:self.document.managedObjectContext
                         queue:nil
                    usingBlock:^(NSNotification *note) {
                        
                        NSLog(@"%@: NSManagedObjectContextObjectsDidChangeNotification",
                              [[UIDevice currentDevice] model]);
                        
                        [self readModelWriteView];
                        
                    }];
    [self.notificationObservers addObject:observer];
}

-(void)ignoreDocument
{
    for (id observer in self.notificationObservers) {
        [[NSNotificationCenter defaultCenter]
         removeObserver:observer];
    }
    [self.notificationObservers removeAllObjects];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle


- (void)viewDidLoad
{
    [super viewDidLoad];
    self.retryCount = 0;
    
    if( nil == self.document ){
        NSLog( @"no document");
        NSAssert( NO, @"no document");
    }else{
        [self observeDocument];
    }
    
    self.textView.delegate = self;
    self.textView.keyboardType = UIKeyboardTypeDefault;
    self.textView.returnKeyType = UIReturnKeyDone;
    
    self.docStateTextField.enabled = NO;
        
    [self resetMocAndParent];
    /** -resetMocAndParent triggers:
        NSManagedObjectContextObjectsDidChangeNotification,
     which triggers:
        [self readModelWriteView]
     */
    
    NSDictionary *metadataDictionary = self.record[NPMetadataDictionaryKey];
    BOOL createdLocally = (nil == metadataDictionary);
    
    if(!createdLocally){
        
        NSURL *cloudDocURL = self.record[NPCloudDocURLKey];
        BOOL started =
        [self.fileManager startDownloadingUbiquitousItemAtURL:cloudDocURL
                                                        error: nil];
        NSLog(@"started = %@", (started ? @"YES" : @"NO"));
        NSAssert( started, @"Failed to start downloading. Better fix this...");

//        NSArray *array =
//        @[NSMetadataUbiquitousItemDownloadingStatusCurrent,
//          NSMetadataUbiquitousItemDownloadingStatusDownloaded,
//          NSMetadataUbiquitousItemDownloadingStatusNotDownloaded];
//        NSMetadataItem *metadataItem = self.record[NPMetadataItemKey];
//        
//        NSString *status = [metadataItem valueForKey: NSMetadataUbiquitousItemDownloadingStatusKey];
//        NSUInteger index = [array indexOfObject: status];
//        switch( index ){
//            case 0: // NSMetadataUbiquitousItemDownloadingStatusCurrent
//            {
//                /**
//                 "... there is a local version of this item and
//                 it is the most up-to-date version known to this device."
//                 */
//            }
//            case 1: // NSMetadataUbiquitousItemDownloadingStatusDownloaded
//            {
//                /**
//                 "...  there is a local version of this item available."
//                 */
//            }
//            case 2: // NSMetadataUbiquitousItemDownloadingStatusNotDownloaded
//            {
//                /**
//                 "... this item has not been downloaded yet."
//                 */
//                
//                // Add a side-effect (mostly harmless):
//                BOOL started =
//                [self.fileManager startDownloadingUbiquitousItemAtURL:cloudDocURL
//                                                                error: nil];
//                NSLog(@"started = %@", (started ? @"YES" : @"NO"));
//                
//                break;
//            }
//            case NSNotFound:
//            default:
//            {
//                NSAssert( NO, @"Programming Error: RTFM");
//                break;
//            }
//        }

    }
    [self readModelWriteView];
    
}

-(void)viewWillDisappear:(BOOL)animated
{
    [self ignoreDocument];
    [super viewWillDisappear: animated];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

#pragma mark - Show Document

-(BOOL)anyUnsavedChanges
{
    TextEntry *textEntry = [self fetchedTextEntry];
    
    if( nil == textEntry ) return NO;
    
    NSString *modelText = textEntry.text;
    NSString *uiText = self.textView.text;
    return  ![modelText isEqualToString: uiText];
}

-(void)readModelWriteView
{
    if( UIDocumentStateNormal == self.document.documentState){
        self.retryCount = 0;
    }
    
    // Perturb the view in the main thread:
    dispatch_async(dispatch_get_main_queue(), ^{
        
        NSMutableString *status = [self.record npStatus].mutableCopy;
        
        TextEntry *textEntry = [self fetchedTextEntry];
        if( nil == textEntry ){
            self.textView.text = @"<nil>";
            [status appendString: @", date?"];
        }else{
            self.textView.text = textEntry.text;
            [status appendFormat: @", %@",[(textEntry.modified) description]];
        }
        
        self.docStateTextField.text = status;
        
        [(self.docStateTextField) setNeedsDisplay];
        [(self.textView)          setNeedsDisplay];
        
        NSLog(@"%@: -readModelWriteView at %@",
              [[UIDevice currentDevice] model],
              [[NSDate date] description]);
        
    }); // end dispatch_async(dispatch_get_main_queue()
}
-(void)readViewWriteModel
{
    /**
     This method checks for differences in text only.
     If there's a difference, it updates the model's TextEntry.text and TextEntry.modified.
     
     */
    TextEntry *textEntryOuter = [self fetchedTextEntry];
    
    if( nil == textEntryOuter ) return;
    
    if( [self anyUnsavedChanges] ){
        
        NSManagedObjectContext *moc = self.document.managedObjectContext;
        
        [moc performBlockAndWait: ^() {
            
            TextEntry *textEntry = [self fetchedTextEntry];
            
            NSLog(@"%@: -readViewWriteModel (changes) at %@",
                  [[UIDevice currentDevice] model],
                  [[NSDate date] description]);
            
            NSUndoManager * undoManager = [moc undoManager];
            
            /*
             For example, in some situations you want to alter—or, specifically, disable—undo behavior. This may be useful if you want to create a default set of objects when a new document is created (but want to ensure that the document is not shown as being dirty when it is displayed), or if you need to merge new state from another thread or process. In general, to perform operations without undo registration, you send an undo manager a disableUndoRegistration message, make the changes, and then send the undo manager an enableUndoRegistration message. Before each, you send the context a processPendingChanges message, as illustrated in the following code fragment:
             
             NSManagedObjectContext *moc = ...;
             [moc processPendingChanges];  // flush operations for which you want undos
             [[moc undoManager] disableUndoRegistration];
             // make changes for which undo operations are not to be recorded
             [moc processPendingChanges];  // flush operations for which you do not want undos
             [[moc undoManager] enableUndoRegistration];

             
             */
            [moc processPendingChanges];
            [undoManager disableUndoRegistration];
            {
                // Actually change the model, but don't "dirty" the document for undo:
                // In this example, undo would just complicate things unnecessarily.
                textEntry.text = self.textView.text;
                textEntry.modified = [NSDate date];
            }
            [moc processPendingChanges];
            [undoManager enableUndoRegistration];
            
            
        }]; //[moc performBlockAndWait:
        
        /*
         
         From Apple's iCloud Desing Guide:
         "If your app design requires explicit control over when pending changes are committed, 
         use the UIDocument method 
            saveToURL:forSaveOperation:completionHandler:.
         If you perform an explicit save operation in an iCloud-enabled app, 
         be aware that you are generating additional network traffic—
         multiplied by the number of devices connected to the iCloud account."

         This app's design goals are to:
         [1] demonstrate cloud-syncing of UIManagedDocuments; and
         [2] get statistics on the latency of cloud-syncing under very simple circumstances.
         So, [2] requires the explicit save operation.
         
         */
        [self.document updateChangeCount: UIDocumentChangeDone];
        [self.document saveToURL: [self.document fileURL]
                forSaveOperation: UIDocumentSaveForOverwriting
               completionHandler:^(BOOL success) {
                   
                   if( success ){
                       NSLog(@"-[DetailViewController readViewWriteModel] Saved changes");
                       
                       /* Results in error:
                        NSUnderlyingError=0x15e90720 "The operation couldn’t be completed. File exists"
                        */
                   }else{
                       NSLog(@"-[DetailViewController readViewWriteModel] Failed to Save changes");
                       
                   }
               }];

    } //if( [self anyUnsavedChanges] )
    
}

#pragma mark UITextViewDelegate for self.text
-(void)finishEditing
{
    [(self.textView) resignFirstResponder];
    [self readViewWriteModel];
}
- (void)textViewDidEndEditing:(UITextView *)aTextView
{
    [self finishEditing];
}
- (BOOL)       textView: (UITextView*) textView
shouldChangeTextInRange: (NSRange) range
        replacementText: (NSString*) text
{
    if ([text isEqualToString:@"\n"]) {
        [self finishEditing];
        return NO;
    }else{
        return YES;
    }
}
@end
