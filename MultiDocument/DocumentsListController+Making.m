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
+(NSDictionary*)cloudPersistentStoreOptionsForRecord: (NSDictionary*)record
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


/**
 This method is not called in this version. It's a sanity check.
 
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
 

 @param document the document to check
 */
-(void)checkPriorKnowledgeAgainstDiscoveredMetadataForDocument: (UIManagedDocument*)document
{
    
    NSAssert( [document isKindOfClass:[UIManagedDocument class]], @"Bogus document.");
    NSDictionary *record = [self recordForDocument: document];

    NSURL *docMDataPlistURL = record[NPCloudDocumentMetadataPlistURLKey];
    
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

    }[self updateTableViewWithRecord: updatedRecord];

}

/**
 This class handles 0 or more documents. Each document has its own set of observers. The document's record stores the document's observers.
 
 
 @param document the document to ignore
 */

-(void)ignoreDocument:(UIManagedDocument*)document
{
    NSNotificationCenter* center =
    [NSNotificationCenter defaultCenter];

    NSMutableDictionary *updatedRecord = [self recordForDocument: document].mutableCopy;
    
    id stateChangedObserver = updatedRecord[NPDocumentStateChangedObserverKey];
    [center removeObserver: stateChangedObserver];
    [updatedRecord removeObjectForKey:NPDocumentStateChangedObserverKey];
    
    id pscImportObserver = updatedRecord[NPDocumentPscImportObserverKey];
    [center removeObserver: pscImportObserver];
    [updatedRecord removeObjectForKey:NPDocumentPscImportObserverKey];
    
    id pscStoresChangedObserver = updatedRecord[NPDocumentPscStoresDidChangeObserverKey];
    [center removeObserver: pscStoresChangedObserver];
    [updatedRecord removeObjectForKey:NPDocumentPscStoresDidChangeObserverKey];
    
    id mocObjectsChangedObserver = updatedRecord[NPDocumentMocObjectsChangedObserverKey];
    [center removeObserver: mocObjectsChangedObserver];
    [updatedRecord removeObjectForKey:NPDocumentMocObjectsChangedObserverKey];
    
    [self updateTableViewWithRecord: updatedRecord];
 
}

/**
 This class handles 0 or more documents. Each document has its own set of observers. The document's record stores the document's observers.

 
 @param document the document to observe
 */
-(void)observeDocument:(UIManagedDocument*)document
{
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
    
    
    NSManagedObjectContext __block *moc = document.managedObjectContext;
    NSPersistentStoreCoordinator *psc = moc.persistentStoreCoordinator;
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
                        
                        [moc performBlock:^{
                            [moc mergeChangesFromContextDidSaveNotification:note];
                        }];
                        
                        
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
                        [self receivedNotification: note
                                          document: document];
                        
                        
                    }];
    updatedRecord[NPDocumentStealthyImportObserverKey] = stealthyImportObserver;

    id pscStoresWillChangeObserver =
    [center addObserverForName:NSPersistentStoreCoordinatorStoresWillChangeNotification
                        object:psc
                         queue:nil
                    usingBlock:^(NSNotification *note) {
                        
                         [moc performBlockAndWait:^{
                            NSError *error;
                            
                            if ([moc hasChanges]) {
                                BOOL success = [moc save:&error];
                                
                                if (!success && error) {
                                    // perform error handling
                                    NSLog(@"%@",[error localizedDescription]);
                                }
                            }
                            
                            [moc reset];
                        }];
                        
                        [self receivedNotification: note
                                          document: document];
                        

                    }];
    updatedRecord[NPDocumentPscStoresWillChangeObserverKey] = pscStoresWillChangeObserver;

    id pscStoresDidChangeObserver =
    [center addObserverForName:NSPersistentStoreCoordinatorStoresDidChangeNotification
                        object:psc
                         queue:nil
                    usingBlock:^(NSNotification *note) {
                        
                        [self receivedNotification: note
                                          document: document];
                       
                    }];
    updatedRecord[NPDocumentPscStoresDidChangeObserverKey] = pscStoresDidChangeObserver;

    
    
    id mocObjectsChangedObserver =
    [center addObserverForName: NSManagedObjectContextObjectsDidChangeNotification
                        object:document.managedObjectContext
                         queue:nil
                    usingBlock:^(NSNotification *note) {
                        
                        [self receivedNotification: note
                                          document: document];
                        
                    }];
    updatedRecord[NPDocumentMocObjectsChangedObserverKey] = mocObjectsChangedObserver;

    [self updateTableViewWithRecord: updatedRecord];
                        
}

-(void)copyDocumentMetadataPlistToCloud: (NSDictionary*)record
{
    UIManagedDocument *doc = record[NPDocumentKey];
    NSAssert( (nil != doc), @"Bogus nil document");
    
    NSFileCoordinator *fCoord = [[NSFileCoordinator alloc] initWithFilePresenter:doc];
    
    NSURL *destURL = record[NPCloudDocumentMetadataPlistURLKey];
    // e.g.,
    // (lldb) po destURL
    // file:///var/mobile/Library/Mobile%20Documents/YHVGV9RUH4~com~nowpicture~multidocument/Documents/89C68DD4-0F34-4CFB-8D57-89531B288979/TestDoc1/DocumentMetadata.plist

    NSError *outError = nil;
    
    [fCoord coordinateWritingItemAtURL: destURL
                               options: NSFileCoordinatorWritingForMoving
                                 error: &outError
                            byAccessor: ^(NSURL *newURL){
  
                                NSURL *destDirURL = [newURL URLByDeletingLastPathComponent];
                                // e.g.,
                                // (lldb) po destDirURL
                                // file:///var/mobile/Library/Mobile%20Documents/YHVGV9RUH4~com~nowpicture~multidocument/Documents/89C68DD4-0F34-4CFB-8D57-89531B288979/TestDoc1/
                                
                                
                                NSError *createError = nil;
                                
                                NSFileManager *fm = [NSFileManager defaultManager];
                                
                                BOOL fileAlreadyExists =
                                [fm fileExistsAtPath: newURL.path];
                                
                                if( !fileAlreadyExists ){
                                    
                                    BOOL successOnCreate =
                                    [fm createDirectoryAtURL: destDirURL
                                 withIntermediateDirectories: YES
                                                  attributes: nil
                                                       error: &createError];
                                    
                                    if( !successOnCreate || (nil!=createError) ){
                                        NSLog( @"createError= %@",
                                              [createError description] );
                                        NSAssert( NO, @"failed to create the directory");
                                        
                                    }else{
                                        NSURL *sourceURL = record[NPLocalDocumentMetadataPlistURLKey];
                                        // e.g.,
                                        // (lldb) po sourceURL
                                        // file:///var/mobile/Applications/1D7E3A9D-6F98-4831-BC4C-1F35BC7165A1/Documents/89C68DD4-0F34-4CFB-8D57-89531B288979/TestDoc1/DocumentMetadata.plist
                                        
                                        NSError *copyError = nil;
                                        BOOL successOnCopy =
                                        [fm copyItemAtURL: sourceURL
                                                    toURL: newURL
                                                    error: &copyError];
                                        
                                        if( !successOnCopy || (nil != copyError) ){
                                            NSLog( @"successOnCopy= %@",
                                                  [copyError description] );
                                            NSAssert( NO, @"failed to copy the URL");
                                        }else{
                                            
                                            // I think the document should now be ubiquitous.
                                        }
                                        
                                    }
                                }

                            
                            }];
}

NSString *NPErrorRecoveryEnabledKey = @"errorRecoveryEnabled";

-(Class)factory
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults synchronize];
    
    BOOL errorRecoveryEnabled = [userDefaults boolForKey: NPErrorRecoveryEnabledKey];
    
    Class factory = nil;
    
    if( errorRecoveryEnabled ){
        factory = [RobustDocument class];
    }else{
        factory = [UIManagedDocument class];
    }
    return factory;
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
    
    NSDictionary *storeOptions = record[NPCloudStoreOptionsKey];
    document.persistentStoreOptions = storeOptions;

    /*
     See: http://www.objc.io/issue-10/icloud-core-data.html
     
     Apple recommends NSMergeByPropertyObjectTrumpMergePolicy, which will merge conflicts, giving priority to in-memory changes over the changes on disk.
     */

    document.managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
    
    {
        // This passage may be superfluous, but seems innocuous.
        // I haven't found Apple Developer document that clarifies the issue.
        
        NSFileCoordinator *haplessCoordinator =
        [[NSFileCoordinator alloc] initWithFilePresenter: document];
        
        // If I don't add this passage, the compiler complains that haplessCoordinator is an unused variable.
        if( !haplessCoordinator ){
            NSAssert( (nil != haplessCoordinator),
                     @"Bogus file coordinator");
        }
        [NSFileCoordinator addFilePresenter: document];
 
    }

    
    NSMutableDictionary *updatedRecord = record.mutableCopy;{
        updatedRecord[NPDocumentKey] = document;

    }[self updateTableViewWithRecord: updatedRecord];
    
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
{
    NSDictionary *record = [self recordForDocument: document];
    
    NSInvocation *successCallback = record[NPSuccessCallbackKey];
    NSInvocation *failCallback = record[NPFailureCallbackKey];
    
    NSURL *localDocURL = record[NPLocalDocURLKey];
    
    NSFileManager *fMgr = [[self class] fileManager];
    
    
    
    NSURL *targetDocURL = nil;
    if( [record npCreatedLocally] ){
        targetDocURL = localDocURL;
    }else{
        targetDocURL = record[NPCloudDocURLKey];
    }
    
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
                                  
                                  // After we close the document, we can no longer use that instance of UIManagedDocument.
                                  // We must instantiate a new one and set its store options again:
                                  
                                  [updatedRecord removeObjectForKey: NPDocumentKey];
                                  document2 =
                                  [self instantiateDocumentFromRecord: updatedRecord];
                                  updatedRecord[NPDocumentKey] = document2;
                                  
                              }[self updateTableViewWithRecord: updatedRecord];
                              
                              // -----------
                              // Some developers find it is unnecessary to "setUbiquitous".
                              // My experience finds that the following call IS necessary.
                              [self copyDocumentMetadataPlistToCloud: updatedRecord];
                              // If I comment the line above,
                              // then OS X Preferences->iCloud [Manage] -> multidocument
                              // shows only a single "Documents & Data" item, and never a list of
                              //    "DocumentMetadata.plist"
                              // items.
                              // -----------
                              
                              /*
                               if( nil != record[NPMetadataDictionaryKey]){
                               [self checkPriorKnowledgeAgainstDiscoveredMetadataForDocument: document2];
                               }
                               */
                              NSLog(@"openWithCompletionHandler: start");
                              [document2 openWithCompletionHandler:^(BOOL success){
                                  
                                  if (!success) {
                                      NSLog(@"In -establishDocument, Error opening file after creating and closing.");
                                      [failCallback invoke];
                                  }else{
                                      NSLog(@"openWithCompletionHandler: succeeded. Opened the created file for reading.");
                                      
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
