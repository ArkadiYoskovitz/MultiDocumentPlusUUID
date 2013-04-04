//
//  DocumentListTableViewController+Making.m
//  MultiDocument
//
//
// This version of MultiDocument derives from Rich Warren's work.
// See: http://www.freelancemadscience.com/fmslabs_blog/2011/12/19/syncing-multiple-core-data-documents-using-icloud.html
//
//  Modified by Don Briggs on 2013 March 22.
//  Copyright (c) 2013.
//

#import "DocumentListTableViewController+Making.h"
#import "DocumentListTableViewController+Resources.h"

#import <CoreData/CoreData.h>

@implementation DocumentListTableViewController (Making)


#pragma mark File Operations:
+(NSDictionary*)localPersistentStoreOptions
{
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES],
                             NSMigratePersistentStoresAutomaticallyOption,
                             [NSNumber numberWithBool:YES],
                             NSInferMappingModelAutomaticallyOption, nil];
    return options;
}

+(NSDictionary*)persistentStoreOptionsForDocumentFileURL: (NSURL*)documentFileURL
{
    // Returns a dictionary:
    // contains localPersistentStoreOptions.
    
    // If self.isCloudEnabled, also contains:
    // { *NameKey = uuid; *URLKey = file:<cloud base>/LogFiles/; }
    // where * = NSPersistentStoreUbiquitousContent.
    
    NSURL *url = documentFileURL;
    
    NSDictionary *options = [self localPersistentStoreOptions];
    
    if( [self isCloudEnabled] ){
        //NSString *ucName = [url lastPathComponent];
        
        NSURL *uuidDir = [url URLByDeletingLastPathComponent];
        NSString *uuid = [uuidDir lastPathComponent];
        
        NSURL *logFilesURL = [self iCloudLogFilesURL];
        NSURL *ucURL = [logFilesURL URLByAppendingPathComponent: uuid];
        
        [self assureDirectoryURLExists: ucURL];
        
        NSMutableDictionary *cloudOptions =
        [NSMutableDictionary dictionaryWithDictionary:options];
        
        [cloudOptions setObject: uuid
                         forKey: NSPersistentStoreUbiquitousContentNameKey];
        [cloudOptions setObject: logFilesURL
                         forKey: NSPersistentStoreUbiquitousContentURLKey];
        
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


+(UIManagedDocument*)instantiateDocumentFromRecord: (NSDictionary*)record
{
    NSURL *localDocURL = [record objectForKey: NPLocalURLKey];
    
    UIManagedDocument* document =
    [[UIManagedDocument alloc] initWithFileURL:localDocURL];
    // This instantiates a UIManagedDocument object
    // But does not save or open it (does not create
    // or read the underlying persistent store).
    
    NSDictionary *storeOptions = [record objectForKey: NPStoreOptionsKey];
    if( nil == storeOptions ){
        storeOptions = [self persistentStoreOptionsForDocumentFileURL: localDocURL];
    }
    document.persistentStoreOptions = storeOptions;
    
    [[document managedObjectContext] setMergePolicy:NSRollbackMergePolicy];

    return document;
}
-(void)saveCreatingSaveOverwriting: (UIManagedDocument*)document
                       initializor: (NSInvocation*)initializor // of the form: -(void)addGraphOfObjectsTo: (UIManagedDocument*)document
                   successCallback: (NSInvocation*)successCallback // of the form -(void)succeeded: (UIManagedDocument*)document
                      failCallback: (NSInvocation*)failCallback // of the form -(void)failed:(UIManagedDocument*)document
{
    [document saveToURL: [document fileURL]
       forSaveOperation: UIDocumentSaveForCreating
      completionHandler:^(BOOL success) {
          if( success ){ // ~12 second latency on save for creating on phone
              
              if( nil != initializor ){
                  [initializor invoke];
              }
              if ([[self class] isCloudEnabled]) {
                  
                  /**
                   Erica Sadun indicates (by omission) that it's unnecessary to setUbiquitous:...
                   I find otherwise.
                   If I skip setUbiquitous:..., 
                   [1] the application's cloud storage "looks wrong" in 
                        the desktop Settings.app; and
                   [2] other devices don't discover supposedly cloud-resident documents. 
                   */

                  NSDictionary *record = [self recordForDocument: document];
                  
                  NSURL *localDocURL = [record objectForKey: NPLocalURLKey];
                  NSURL* cloudDocURL = [record objectForKey: NPCloudURLKey];

                  dispatch_queue_t queue =
                  dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
                  
                  dispatch_async(queue, ^{
                  
                      NSError* error = nil;
                      
                      if (![[[self class] fileManager] setUbiquitous: YES
                                                           itemAtURL: localDocURL
                                                      destinationURL: cloudDocURL
                                                               error: &error] ) {
                          
                          [NSException
                           raise:NSGenericException
                           format:@"Error moving to iCloud container: %@",
                           error.localizedDescription];
                      }
                      
                  });
              }
              [document saveToURL: [document fileURL]
                 forSaveOperation: UIDocumentSaveForOverwriting
                completionHandler:^(BOOL success) {
                    
                    if( success ){
                        NSLog(@"Saved for overwriting");
                        
                        [successCallback invoke];
                        
                    }else{
                        NSLog(@"Failed to Save for overwriting");
                        [failCallback invoke];
                    }
                }];

          }else{
              [failCallback invoke];
          }
      }];
}
-(void)establishDocument: (UIManagedDocument*)document
         successCallback: (NSInvocation*)successCallback
            failCallback: (NSInvocation*)failCallback;
{
    
    NSMutableDictionary *record = [self recordForDocument: document];
    [record setObject: document
               forKey: NPDocumentKey];
    
    NSURL *localDocURL = [record objectForKey: NPLocalURLKey];
    if ([[[self class] fileManager] fileExistsAtPath: localDocURL.path]){
        
        NSLog(@"Attempting to open existing file");
        
        [document openWithCompletionHandler:^(BOOL success){
            if (!success) {
                NSLog(@"In -establishDocument:, Error opening file");
                return;
                [failCallback invoke];
            }else{
                NSLog(@"File opened");
                [successCallback invoke];
            }
            
        }]; //openWithCompletionHandler
        
    }else{
        NSLog(@"Creating file.");
        // 1. save it  (creating), 2. close it, 3. read it back in.
        
        [document saveToURL: localDocURL
           forSaveOperation:UIDocumentSaveForCreating
          completionHandler:^(BOOL success){
              if (!success) {
                  NSLog(@"In -establishDocument, Error creating file");
                  [failCallback invoke];
              }else{
                  NSLog(@"File created");
                  
                  if( [[self class] isCloudEnabled] ){
                      
                      [document closeWithCompletionHandler:^(BOOL success){
                          NSLog(@"Closed new file: %@", success ? @"Success" : @"Failure");
                          
                          if (!success) {
                              NSLog(@"In -establishDocument, Error closing file after creating.");
                              [failCallback invoke];
                          }else{
                              NSURL *cloudURL = [record objectForKey: NPCloudURLKey];
                              if( nil == cloudURL ){
                                  cloudURL = [[self class] cloudDocURLForFileName: [record objectForKey: NPFileNameKey]
                                                                             uuid: [record objectForKey: NPUUIDKey]];
                                  [record setObject: cloudURL
                                             forKey: NPCloudURLKey];
                              }
                              
                              NSURL *localDocURL = [record objectForKey: NPLocalURLKey];
                              
                              // If we initialized and saved (saved-for-creating) and closed the doc with
                              // the cloud version of persistent store options,
                              // the cloudDocUuidURL should exist already:
                              
                              NSURL* cloudDocURL = [record objectForKey: NPCloudURLKey];
                              NSURL* cloudDocUuidURL = [cloudDocURL URLByDeletingLastPathComponent];
                              [[self class] assureDirectoryURLExists: cloudDocUuidURL];
                              
                              NSError* error = nil;
                              
                              BOOL success = [[[self class] fileManager] setUbiquitous: YES
                                                                             itemAtURL: localDocURL
                                                                        destinationURL: cloudDocURL
                                                                                 error: &error];
                              if (!success) {
                                  [failCallback invoke];
                                  
                              }
                              
                              // After we close the doc, we can no longer use that instance.
                              // We must instantiate a new one and set its store options again:
                              
                              [record removeObjectForKey: NPDocumentKey];
                              UIManagedDocument *document2 =
                              [[self class] instantiateDocumentFromRecord: record];
                              [record setObject: document2
                                         forKey: NPDocumentKey];
                              
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
                      }]; // closeWithCompletionHandler:
                      
                      
                  } // if( [[self class] isCloudEnabled] )
                  
              }
          }]; //saveToURL:saveCreating:completionHandler:
    }
    NSLog( @"-establishDocument: END ");
    
}
@end
