//
//  DocumentsListController+Making.m
//  MultiDocumentPlusUUID

//
//
// MultiDocumentPlusUUID derives from Rich Warren's MultiDocument example.
// See: http://www.freelancemadscience.com/fmslabs_blog/2011/12/19/syncing-multiple-core-data-documents-using-icloud.html
//
//  Modified by Don Briggs on 2013 March 22.
//  Copyright (c) 2014 Don Briggs. All rights reserved.
//

#import "DocumentsListController+Making.h"
#import "DocumentsListController+Resources.h"
#import "DocumentsListController+ErrorRecovering.h"

#import <CoreData/CoreData.h>

#import "RobustDocument.h"

#import "NSDictionary+NPAssisting.h"

@implementation DocumentsListController (Making)

#pragma mark File Operations:

+(NSDictionary*)localPersistentStoreOptions
{
    NSDictionary *options = @{NSMigratePersistentStoresAutomaticallyOption: @YES,
                             NSInferMappingModelAutomaticallyOption: @YES};
    return options;
}
+(NSDictionary*)persistentStoreOptionsForRecord: (NSDictionary*)record
{
    // Returns a dictionary:
    // contains localPersistentStoreOptions.
    
    // If self.isCloudEnabled, also contains:
    // { *NameKey = uuid; *URLKey = file:<cloud base>/LogFiles/; }
    // where * = NSPersistentStoreUbiquitousContent.
    
    NSDictionary *options = [self localPersistentStoreOptions];
    
    if( [self isCloudEnabled] ){
        //NSString *ucName = [url lastPathComponent];
        
        NSURL *url = record[NPCloudDocURLKey];
        
        NSURL *uuidDir = [url URLByDeletingLastPathComponent];
        NSString *uuid = [uuidDir lastPathComponent];
        
        NSURL *logFilesURL = [self iCloudLogFilesURL];
        NSURL *ucURL = [logFilesURL URLByAppendingPathComponent: uuid];
        
        [self assureDirectoryURLExists: ucURL];
        
        NSMutableDictionary *cloudOptions =
        [NSMutableDictionary dictionaryWithDictionary:options];
        
        cloudOptions[NSPersistentStoreUbiquitousContentNameKey] = uuid;
        cloudOptions[NSPersistentStoreUbiquitousContentURLKey]  = logFilesURL;
        
        options = [cloudOptions copy];
        /* Example result:
         
         (gdb) po options
         {
         NSInferMappingModelAutomaticallyOption = 1;
         NSMigratePersistentStoresAutomaticallyOption = 1;
         NSPersistentStoreUbiquitousContentNameKey = "C1F6892B-6118-4868-8F87-A690EDAD844A";
         NSPersistentStoreUbiquitousContentURLKey = "file://localhost/private/var/mobile/Library/Mobile%20Documents/YHVGV9RUH4~com~nowpicture~multidocument/LogFiles/";
         }
         
         */
    }
    return options;
}


-(void)checkPriorKnowledgeAgainstDiscoveredMetadataForDocument: (UIManagedDocument*)document
{
    
    /**
     Apple Documentation:
     "To open a document that uses the SQLite store, you must retrieve the value of the NSPersistentStoreUbiquitousContentNameKey from the DocumentMetadata.plist file and set that content name key in the persistentStoreOptions dictionary before you open the document with openWithCompletionHandler:."
     
     That's discovered knowledge.
     The approach I favor uses prior knowledge instead.
     We can compute the the document's NSPersistentStoreUbiquitousContentNameKey
     from its URL path components.

     Therefore, at least in early development, it might be good to check
     prior knowledge against discovered knowledge 
     with a method like this one.
     
     This would be unnecessary in deployment, 
     but it might prove helpful--even if merely reassuring--in development.
     
     */
    NSAssert( [document isKindOfClass:[UIManagedDocument class]], @"Bogus document.");
    NSDictionary *record = [self recordForDocument: document];

    NSURL *docMDataPlistURL = [record[NPCloudDocURLKey] URLByAppendingPathComponent: @"DocumentMetadata.plist"];
    NSAssert( [docMDataPlistURL isKindOfClass:[NSURL class]], @"Bogus URL for documentMetadata.plist.");
    
    NSDictionary *discoveredDocMDataDict = [NSDictionary dictionaryWithContentsOfURL:docMDataPlistURL];
    NSAssert( [discoveredDocMDataDict isKindOfClass:[NSDictionary class]], @"Bogus NSDictionary from documentMetadata.plist.");

    
    NSString *contentName =
    discoveredDocMDataDict[NSPersistentStoreUbiquitousContentNameKey];
    
    if( [contentName isKindOfClass:[NSString class]] && (0 != contentName.length) ){
        
        NSMutableDictionary *tmp = document.persistentStoreOptions.mutableCopy;
        tmp[NSPersistentStoreUbiquitousContentNameKey] = contentName;
        document.persistentStoreOptions = tmp;
    }
    
    NSURL *contentURL =
    discoveredDocMDataDict[NSPersistentStoreUbiquitousContentURLKey];
    if( [contentURL isKindOfClass:[NSString class]]
       && (0 != contentURL.absoluteString.length)){
        
        NSMutableDictionary *tmp = document.persistentStoreOptions.mutableCopy;
        tmp[NSPersistentStoreUbiquitousContentURLKey] = contentURL;
        document.persistentStoreOptions = tmp;
    }
    
}
-(void)receivedNotification: (NSNotification*)note
                   document: (UIManagedDocument*)document
{
    NSMutableDictionary *updatedRecord = [[self recordForDocument:document] mutableCopy];{
        
        // When is the object graph of a disovered document avalable for inspection?
        // The entire dictionary named NPNotificationDates may be overkill,
        // because the pertinent signal seems to be the arrival of the notification named
        // "com.apple.coredata.ubiquity.importer.didfinishimport".
        // See also: -[NSDictionary+NPAssisting isDocumentViewable]

        if( [note.name isEqualToString: NPStealthyDidFinishImport] ){
            
            /**
             Came from
             id pscImportObserver =
             [center addObserverForName:NSPersistentStoreDidImportUbiquitousContentChangesNotification
                                 object:psc
                                  queue:nil
                             usingBlock:^(NSNotification *note) {
             
                  [self receivedNotification: note
                                    document: document];
             
             
             }];
             
             (lldb) po note
             NSConcreteNotification 0x165ea720 {name = com.apple.coredata.ubiquity.importer.didfinishimport; object = <NSPersistentStoreCoordinator: 0x16695b40>; userInfo = {
             deleted = "{(\n)}";
             inserted = "{(\n    0x16586180 <x-coredata://E24729CE-4C32-4961-A228-005264DCA31B/ModelVersion/p2>,\n    0x165de350 <x-coredata://E24729CE-4C32-4961-A228-005264DCA31B/TextEntry/p2>\n)}";
             updated = "{(\n)}";
             }}

             */
            NSLog(@"NPStealthyDidFinishImport: \n%@", [note description]);
        }
        // An inner dictionary has entries of the form:
        // @{ <notification name i>: <date i>, <notification name j>: <date j>, ...}
        
        NSMutableDictionary *notificationDates = nil;
        {
            id test = updatedRecord[NPNotificationDates];
            if( [test isKindOfClass: [NSDictionary class]] ){
                notificationDates = ((NSMutableDictionary*)test).mutableCopy;
            }else{
                notificationDates = [NSMutableDictionary dictionaryWithCapacity: 4];
            }
            
            notificationDates[note.name] = [NSDate date];
        }
        updatedRecord[NPNotificationDates] = notificationDates;

    }[self updateRecord: updatedRecord];

    [(self.tableView) reloadData];
    [(self.tableView) setNeedsDisplay];
    
    [self resetTableViewSnoozeAlarm];
}

-(void)ignoreDocument:(UIManagedDocument*)document
{
    /**
     This class handles 0 or more documents.
     Each document has its own set of observers.
     The document's record stores the document's observers.
     */
    NSNotificationCenter* center =
    [NSNotificationCenter defaultCenter];

    NSMutableDictionary *updatedRecord = [self recordForDocument: document].mutableCopy;
    
    id stateChangedObserver = updatedRecord[NPDocumentStateChangedObserverKey];
    [center removeObserver: stateChangedObserver];
    [updatedRecord removeObjectForKey:NPDocumentStateChangedObserverKey];
    
    id pscImportObserver = updatedRecord[NPDocumentPscImportObserverKey];
    [center removeObserver: pscImportObserver];
    [updatedRecord removeObjectForKey:NPDocumentPscImportObserverKey];
    
    id pscStoresChangedObserver = updatedRecord[NPDocumentPscStoresChangedObserverKey];
    [center removeObserver: pscStoresChangedObserver];
    [updatedRecord removeObjectForKey:NPDocumentPscStoresChangedObserverKey];
    
    id mocObjectsChangedObserver = updatedRecord[NPDocumentMocObjectsChangedObserverKey];
    [center removeObserver: mocObjectsChangedObserver];
    [updatedRecord removeObjectForKey:NPDocumentMocObjectsChangedObserverKey];
    
    [self updateRecord: updatedRecord];
 
}
-(void)observeDocument:(UIManagedDocument*)document
{
    /**
     This class handles 0 or more documents.
     Each document has its own set of observers.
     The document's record stores the document's observers.
     */

    NSAssert( (nil !=document),
             @"-[%@ observeDocument] found nil document",
             NSStringFromClass([self class]));

    [self ignoreDocument: document];
    
    NSMutableDictionary *updatedRecord = [self recordForDocument: document].mutableCopy;

    NSNotificationCenter* center =
    [NSNotificationCenter defaultCenter];
    
    id stateChangedObserver =
    [center addObserverForName:UIDocumentStateChangedNotification
                        object:document
                         queue:nil
                    usingBlock:^(NSNotification *note) {
                        
                       [self receivedNotification: note
                                         document: document];
                        
                    }];
    updatedRecord[NPDocumentStateChangedObserverKey] = stateChangedObserver;
    
    
    NSPersistentStoreCoordinator *psc =
    document.managedObjectContext.persistentStoreCoordinator;
    NSAssert( (nil !=psc),
             @"-[%@ observeDocument] found nil psc",
             NSStringFromClass([self class]));
    
    id pscImportObserver =
    [center addObserverForName:NSPersistentStoreDidImportUbiquitousContentChangesNotification
                        object:psc
                         queue:nil
                    usingBlock:^(NSNotification *note) {
                        
                        [self receivedNotification: note
                                          document: document];
                        
                        
                    }];
    updatedRecord[NPDocumentPscImportObserverKey] = pscImportObserver;
    
    id stealthyImportObserver =
    [center addObserverForName:NPDocumentStealthyImportObserverKey
                        object:psc
                         queue:nil
                    usingBlock:^(NSNotification *note) {
                        
                        // Check the documentation:
                        // see ReadMore.pdf
                        // Updates for iOS 7.1 (11D5145e)
                        //
                        // Umm... In 7.1.1 (11D201), I no longer receive a
                        // notification named:
                        // "com.apple.coredata.ubiquity.importer.didfinishimport"
                        //
                        [self receivedNotification: note
                                          document: document];
                        
                        
                    }];
    updatedRecord[NPDocumentStealthyImportObserverKey] = stealthyImportObserver;

    id pscStoresChangedObserver =
    [center addObserverForName:NSPersistentStoreCoordinatorStoresDidChangeNotification
                        object:psc
                         queue:nil
                    usingBlock:^(NSNotification *note) {
                        
                        [self receivedNotification: note
                                          document: document];
                       
                    }];
    updatedRecord[NPDocumentPscStoresChangedObserverKey] = pscStoresChangedObserver;

    
    
    id mocObjectsChangedObserver =
    [center addObserverForName: NSManagedObjectContextObjectsDidChangeNotification
                        object:document.managedObjectContext
                         queue:nil
                    usingBlock:^(NSNotification *note) {
                        
                        [self receivedNotification: note
                                          document: document];
                        
                    }];
    updatedRecord[NPDocumentMocObjectsChangedObserverKey] = mocObjectsChangedObserver;

    [self updateRecord: updatedRecord];
                        
}

/**
 See: Document-Based Programming GUide for iOS: Managing the Life Cycle of a Document
 
 "Moving a Document to iCloud Storage
 Programmatically, you put a document in iCloud storage by calling the NSFileManager method setUbiquitous:itemAtURL:destinationURL:error:. This method requires the file URL of the document file in the application sandbox (source URL) and the destination file URL of the document file in the application’s iCloud container directory. The first parameter takes a Boolean value, which should be YES.
 
 Important: You should not call setUbiquitous:itemAtURL:destinationURL:error: from your application’s main thread, especially if the document is not closed. Because this method performs a coordinated write operation on the specified file, calling this method from the main thread can trigger a deadlock with any file presenter monitoring the file. (In addition, this method executing on the main thread can take an indeterminate amount of time to complete.) Instead, call the method in a block running in a dispatch queue other than the main-thread queue. You can always message your main thread after the call finishes to update the rest of your application’s data structures."
 
 See Listing 4-9  Moving a document file to iCloud storage from local storage.
 
 @param record the document's helper dictionary
 */
-(void)setUbiquitous: (NSDictionary*)record
{
    
    if ([[self class] isCloudEnabled]) {
        
        NSURL *localDocURL = record[NPLocalDocURLKey];//[record objectForKey: NPLocalDocURLKey];
        [[self class] assureDirectoryURLExists: localDocURL];
        
        NSURL* cloudDocURL = record[NPCloudDocURLKey];
        
        // Just checking:
//        BOOL isMainThread = [[NSThread currentThread] isMainThread];
//        NSLog(@"Main Thread: %@", isMainThread ? @"YES" : @"NO");
        
        
        // 2014 mar 27 test:
        dispatch_queue_t queue =
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        
        dispatch_async(queue, ^{
        
            //NSLog(@" -setUbiquitous:error: dispatch_async start");
            NSLog(@" in dispatch_async  -setUbiquitous:error: ");
            
            
            NSFileManager *fm = [[NSFileManager alloc] init];
            
            NSError *error = nil;
            BOOL success =
            [fm setUbiquitous: YES
                    itemAtURL: localDocURL
               destinationURL: cloudDocURL //coordinatedCloudDocURL
                        error: &error];
            
            if(success){
                NSLog(@" in dispatch_async -setUbiquitous:error: SUCCESS");
                
                // 2014 Mar 24 Investigating:
                success = [fm startDownloadingUbiquitousItemAtURL: cloudDocURL
                                                            error: &error];
                if(success){
                    NSLog(@" in dispatch_async startDownloadingUbiquitousItemAtURL SUCCESS");
                }
            }else{
                NSLog(@" in dispatch_async -setUbiquitous:error: FAIL: %@", [error description]);
                [NSException
                 raise:NSGenericException
                 format:@"Error moving to iCloud container: %@",
                 error.localizedDescription];
                
            }
            
            NSLog(@" in dispatch_async -setUbiquitous:error: end");
            
        });
        
        NSLog(@"-setUbiquitous: async queue did dispatch");
    }
}

-(void)mostlyHarmlessMethod: (NSString*)haplessArgument
{
    // Strive to do nothing in this method.
    // Just do nothing.
}
-(UIManagedDocument*)instantiateDocumentFromRecord: (NSDictionary*)record
{
    // This method instantiates a UIManagedDocument (or a RobustDocument) object
    // But does not save or open it
    // (does not create or read the underlying persistent store).

    // Error recovery requires a subclass of UIManagedDocument.
    // A Settings preference enables use of RobustDocument:UIManagedDocument
    Class factory = [self factory]; // for error recovery only.
    
    // This method, -instantiateDocumentFromRecord:,
    // is the only place we call -[UIManagedDocument initWithFileURL:]
    UIManagedDocument* document =
    [[factory alloc] initWithFileURL: record[NPLocalDocURLKey]];
    
    NSAssert( [document isKindOfClass:[UIManagedDocument class]],
             @"Bogus factory class");
    
    NSDictionary *storeOptions = record[NPStoreOptionsKey];

    document.persistentStoreOptions = storeOptions;
    
    NSFileCoordinator *haplessCoordinator =
    [[NSFileCoordinator alloc] initWithFilePresenter: document];
    
    // If I don't add this passage, the compiler complains that haplessCoordinator is an unused variable.
    if( !haplessCoordinator ){
        NSAssert( (nil != haplessCoordinator),
                 @"Bogus file coordinator");
    }
    [NSFileCoordinator addFilePresenter: document];

    
    NSMutableDictionary *updatedRecord = record.mutableCopy;
    updatedRecord[NPDocumentKey] = document;
    [self updateRecord: updatedRecord];
    
    [self observeDocument: document];
    
    [[document managedObjectContext] setMergePolicy:NSRollbackMergePolicy];
    
    /*
     In Apple's iCloud Design Guide, we find:
     
     App Responsibilities for Using iCloud Documents
     Changes to your app’s documents can arrive from iCloud at any time, so your app must be prepared to handle them. The NSDocument class in OS X does most of this work for you, while in iOS there is more for your app to handle explicitly. Follow these guidelines:
     
     Enable Auto Save. 
     For your app to participate with iCloud, you must enable Auto Save.
     In iOS, enable Auto Save by registering with the default NSUndoManager object or else by calling the UIDocument method updateChangeCount: at appropriate points in your code, such as when a view moves off the screen or your app transitions to the background.
     */
    [(document.undoManager) registerUndoWithTarget: self
                                          selector: @selector(mostlyHarmlessMethod:)
                                            object:@"foo"];
    return document;
}
-(void)establishDocument: (UIManagedDocument*)document
         successCallback: (NSInvocation*)successCallback
            failCallback: (NSInvocation*)failCallback
{
    NSDictionary *record = [self recordForDocument: document];
    NSURL *localDocURL = record[NPLocalDocURLKey];
    
    NSFileManager *fMgr = [[self class] fileManager];
    
    if( [fMgr fileExistsAtPath: [localDocURL path]]){
        [document openWithCompletionHandler:^(BOOL success){
            
            if (!success) {
                NSLog(@"In -establishDocument:, Error opening file");
                return;
                [failCallback invoke];
            }else{
                
                NSLog(@"File opened");
                [successCallback invoke];
            }
            
        }];
    }else{
        [document saveToURL: localDocURL
           forSaveOperation: UIDocumentSaveForCreating
          completionHandler:^(BOOL success){
              
              
              if (!success) {
                  NSLog(@"In -establishDocument, Error creating file");
                  [failCallback invoke];
              }else{
                  NSLog(@"Saved new document for creating");
                  
                  if( [record npCreatedLocally] ){
                      [self addObjectGraphToDocument: document];
                      
                      [document closeWithCompletionHandler:^(BOOL success){
                          NSLog(@"Closed new document: %@", success ? @"Success" : @"Failure");
                          
                          if (!success) {
                              NSLog(@"In -establishDocument, Error closing file after creating.");
                              [failCallback invoke];
                          }else{
                              [self ignoreDocument: document];
                                                            
                              UIManagedDocument *document2 = nil;
                              NSMutableDictionary *updatedRecord = record.mutableCopy;{
                                  
                                  // Some developers find it is unnecessary to "setUbiquitous".
                                  // My experience finds that the following call IS necessary.
                                  [self setUbiquitous: record];
                                  // If I comment the line above,
                                  // then OS X Preferences->iCloud [Manage] -> multidocument
                                  // shows only a single "Documents & Data" item, and never a list of
                                  //    "DocumentMetadata.plist"
                                  // items.
                                  
                                  // After we close the document, we can no longer use that instance of UIManagedDocument.
                                  // We must instantiate a new one and set its store options again:
                                  
                                  [updatedRecord removeObjectForKey: NPDocumentKey];
                                  document2 =
                                  [self instantiateDocumentFromRecord: updatedRecord];
                                  updatedRecord[NPDocumentKey] = document2;
                                  
                              }[self updateRecord: updatedRecord];
                              
                              
                              /*
                               if( nil != record[NPMetadataDictionaryKey]){
                               [self checkPriorKnowledgeAgainstDiscoveredMetadataForDocument: document2];
                               }
                               */
                              NSLog(@"openWithCompletionHandler:");
                              [document2 openWithCompletionHandler:^(BOOL success){
                                  
                                  if (!success) {
                                      NSLog(@"In -establishDocument, Error opening file after creating and closing.");
                                      [failCallback invoke];
                                  }else{
                                      NSLog(@"Opened created file for reading.");
                                      
                                      [successCallback invoke];
                                      
                                  }
                                  
                              }]; //open handler
                          } //if( close->success )
                      }]; // close
                      
                  }else{ // if locally created
                      [successCallback invoke];
                  }
                  
              }
              
              
          }]; // save for creating
        
    }
}



@end
