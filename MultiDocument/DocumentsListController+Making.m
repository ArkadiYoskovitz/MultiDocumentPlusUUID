//
//  DocumentsListController+Making.m
//  MultiDocumentPlusUUID

//
//
// MultiDocumentPlusUUID derives from Rich Warren's MultiDocument example.
// See: http://www.freelancemadscience.com/fmslabs_blog/2011/12/19/syncing-multiple-core-data-documents-using-icloud.html
//
//  Modified by Don Briggs on 2013 March 22.
//  Copyright (c) 2013.
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
        
        // It doesn't work to use <uuid>/<fileName> as the ucn.
        //        NSString *ucn = [NSString stringWithFormat: @"%@/%@",
        //                         uuid, [url lastPathComponent]];
        //        cloudOptions[NSPersistentStoreUbiquitousContentNameKey] = ucn;
        // We get a lot of
        // > Confused by: UzX9BeaCI2Ev...blah
        // Just use the uuid.
        
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
     I compute the the document's NSPersistentStoreUbiquitousContentNameKey
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
    
    [self updateRecord: updatedRecord];
 
}
-(void)observeDocument:(UIManagedDocument*)document
{
    /**
     This class handles 0 or more documents.
     Each document has its own set of observers.
     The document's record stores the document's observers.
     */

    [self ignoreDocument: document];
    
    NSMutableDictionary *updatedRecord = [self recordForDocument: document].mutableCopy;

    NSNotificationCenter* center =
    [NSNotificationCenter defaultCenter];
    
    id stateChangedObserver =
    [center addObserverForName:UIDocumentStateChangedNotification
                        object:document
                         queue:nil
                    usingBlock:^(NSNotification *note) {
                        
                       [self resetTableViewSnoozeAlarm];
                        
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
                        
                        NSMutableDictionary *updatedRecord = [[self recordForDocument:document] mutableCopy];
                        updatedRecord[NPMostRecentUpdateKey] = [NSDate date];
                        [self updateRecord: updatedRecord];
                        
                        [self resetTableViewSnoozeAlarm];
                        
                    }];
    updatedRecord[NPDocumentPscImportObserverKey] = pscImportObserver;
    
    [self updateRecord: updatedRecord];
                        
}

-(void)setUbiquitous: (NSDictionary*)record
{
    
    if ([[self class] isCloudEnabled]) {
                
        NSURL *localDocURL = record[NPLocalDocURLKey];//[record objectForKey: NPLocalDocURLKey];
        [[self class] assureDirectoryURLExists: localDocURL];
        
        NSURL* cloudDocURL = [record objectForKey: NPCloudDocURLKey];
        
        
        dispatch_queue_t queue =
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        
        dispatch_async(queue, ^{
            
            NSLog(@" -setUbiquitous:error: dispatch_async start");
            
            /**
             DON'T DO THIS:
             
             
             BECAUSE:
             
             "Printing description of error:
             *** Terminating app due to uncaught exception 'NSInternalInconsistencyException', reason: 'This NSPersistentStoreCoordinator has no persistent stores.  It cannot perform a save operation.'
             *** First throw call stack:
             (0x308b2e8b 0x3abac6c7 0x306094c9 0x3062adb1 0x3352e3bf 0x3068e855 0x3b0910ef 0x3b0958fb 0x3068e993 0x3352e141 0x3352da85 0x334f051b 0x31319fef 0x3131a28f 0x3131b2a3 0x3131bae3 0x3131a231 0x334efa63 0x334f0233 0x3b091103 0x3b095e77 0x3b092f9b 0x3b096751 0x3b0969d1 0x3b1c0dff 0x3b1c0cc4)
             libc++abi.dylib: terminating with uncaught exception of type NSException"
             


            NSFileCoordinator *fc =
            [[NSFileCoordinator alloc] initWithFilePresenter:record[NPDocumentKey]];
            
            [fc coordinateWritingItemAtURL:cloudDocURL
                                   options:NSFileCoordinatorWritingForMerging
                                     error:nil
                                byAccessor:^(NSURL *coordinatedCloudDocURL) {
                                    
                   */
                                    NSFileManager *fm = [[NSFileManager alloc] init];
                                    
                                    NSError *error = nil;
                                    BOOL success =
                                    [fm setUbiquitous: YES
                                            itemAtURL: localDocURL
                                       destinationURL: cloudDocURL //coordinatedCloudDocURL
                                                error: &error];
                                    
                                    if(success){
                                        NSLog(@" -setUbiquitous:error: SUCCESS");
                                    }else{
                                        NSLog(@" -setUbiquitous:error: FAIL: %@", [error description]);
                                        [NSException
                                         raise:NSGenericException
                                         format:@"Error moving to iCloud container: %@",
                                         error.localizedDescription];
                                        
                                    }

                           /**     }]; Matching  [fc coordinateWritingItemAtURL:.. */
            NSLog(@" -setUbiquitous:error: dispatch_async end");
            
        });
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
//    if( nil == storeOptions ){
//        storeOptions =
//        [[self class] persistentStoreOptionsForRecord: record];
//    }
    document.persistentStoreOptions = storeOptions;
    
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
            failCallback: (NSInvocation*)failCallback;
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
                
                NSMutableDictionary *updatedRecord = record.mutableCopy;
                [updatedRecord removeObjectForKey: NPMostRecentUpdateKey];
                [self updateRecord: updatedRecord];
                
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
                  NSLog(@"File created");
                  
                  if( [record npCreatedLocally] ){
                      [self addObjectGraphToDocument: document];
                      
                      NSMutableDictionary *updatedRecord = record.mutableCopy;
                      updatedRecord[NPMostRecentUpdateKey] = [NSDate date];
                      [self updateRecord: updatedRecord];
                      
                      
                      [document closeWithCompletionHandler:^(BOOL success){
                          NSLog(@"Closed new file: %@", success ? @"Success" : @"Failure");
                          
                          if (!success) {
                              NSLog(@"In -establishDocument, Error closing file after creating.");
                              [failCallback invoke];
                          }else{
                              NSURL *cloudDocURL = record[NPCloudDocURLKey];
                              
                              UIManagedDocument *document2 = nil;
                              NSMutableDictionary *updatedRecord = record.mutableCopy;{
                                  
                                  if ([[[self class] fileManager] fileExistsAtPath: cloudDocURL.path]){
                                      [updatedRecord removeObjectForKey: NPMostRecentUpdateKey];
                                  }else{
                                      [self setUbiquitous: record];
                                      [updatedRecord setObject: [NSDate date] forKey: NPMostRecentUpdateKey];
                                  }
                                  
                                  // After we close the doc, we can no longer use that instance.
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
