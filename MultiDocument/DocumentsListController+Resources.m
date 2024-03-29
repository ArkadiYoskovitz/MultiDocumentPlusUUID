//
//  DocumentsListController+Resources.m
//  MultiDocumentPlusUUID

//
//
// MultiDocumentPlusUUID derives from Rich Warren's MultiDocument example.
// See: http://www.freelancemadscience.com/fmslabs_blog/2011/12/19/syncing-multiple-core-data-documents-using-icloud.html
//
//  Modified by Don Briggs on 2013 March 22.
//  Copyright (c) 2014 Don Briggs. All rights reserved.
//

#import "DocumentsListController+Resources.h"
#import "DocumentsListController+Querying.h"


#import "NSURL+NPAssisting.h"

@implementation DocumentsListController (Resources)

/**
 Returns an instance of NSFilemanager. It's thread-safe.
 
 Note:
 "Threading Considerations
 The methods of the shared NSFileManager object can be called from multiple threads safely. However, if you use a delegate to receive notifications about the status of move, copy, remove, and link operations, you should create a unique instance of the file manager object, assign your delegate to that object, and use that file manager to initiate your operations."
 
 @return thread-safe file manager
 */
+(NSFileManager*)fileManager
{    
    return [NSFileManager defaultManager];
}

+(void)actuallyCreateDirectoryAtURL: (NSURL*)url
{
    
    NSError *error = nil;
    BOOL result = [[self fileManager] createDirectoryAtURL: url
                              withIntermediateDirectories: YES
                                               attributes: nil
                                                    error: &error];
    
    BOOL somethingBadHappened = (nil != error) || !result;
    if( somethingBadHappened ){
        NSLog( @" Can't create directory: %@", url.path );
        NSLog( @" error = %@", [error description] );
    }
    NSAssert( result, @" Can't create directory: %@", url.path );
}

+(BOOL)assureDirectoryURLExists: (NSURL*)url
{
    
    if( nil == url ){
        NSAssert( (nil!=url), @"Bogus url argument is nil");
        return NO;
    }
    
    if( ![url isKindOfClass:[NSURL class]] ){
        NSAssert( [url isKindOfClass:[NSURL class]],
                 @"Bogus url argument is not NSURL: %@", NSStringFromClass([url class]) );

    }
    
    BOOL result = NO;
    BOOL isDir = NO;
    
    NSURL *urlPrime = [url npNormalizedURL];
    
    BOOL exists = [[self fileManager] fileExistsAtPath: urlPrime.path
                                           isDirectory: &isDir];
    if( !exists ){
        //NSLog(@"directory does NOT exist, creating: %@", url.path);
        
        [self actuallyCreateDirectoryAtURL: url];
        result = YES;
    }

    if( exists && isDir ){
        //NSLog(@"directory exists: %@", url.path);
        result = YES;
        
    }
    if( exists && !isDir ){
        //NSLog(@"file url exists, but is NOT a directory: %@", url.path);
        result = NO;
        
    }
   return result;
}

static NSURL *mm_containerURL = nil;

+(void)getContainerURLWithCallback: (NSInvocation*)callback
{
    
    NSDate *start = [[NSDate date] copy];
    
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        
        
        NSFileManager *fMgr = [[self class] fileManager];
        mm_containerURL =
        [[fMgr URLForUbiquityContainerIdentifier: nil] npNormalizedURL];
        
        NSDate *complete = [NSDate date];
        
        NSTimeInterval dT =
        [complete timeIntervalSinceReferenceDate] -
        [start timeIntervalSinceReferenceDate];
        
        NSLog(@" latency for -[NSFileManager URLForUbiquityContainerIdentifier:] = %f", dT);
        // In iOS 6 on iPhone 4:
        // The lowest I saw was about 0.2 sec.
        // The highest was about 3.3 sec.
        
        // Faster in iOS 7 on iPhone 5
        // lowest about 0.1 sec
        
        NSLog(@"mm_containerURL = %@", [mm_containerURL description]);
        
        [callback invoke];
        
    });
}
+ (NSURL*)containerURL {
    return mm_containerURL;
}

+ (NSURL *)iCloudDocumentsURL
{
    static NSURL *mm_iCloudDocumentsURL = nil;
    if( nil == mm_iCloudDocumentsURL ){
        
        NSURL *result = [self containerURL];
        
        result =
        [result URLByAppendingPathComponent: @"Documents"
                                isDirectory:YES];
        
        mm_iCloudDocumentsURL = [[result npNormalizedURL] copy];
        [self assureDirectoryURLExists: mm_iCloudDocumentsURL];
        
    }
    return mm_iCloudDocumentsURL;
}
+ (NSURL *)iCloudLogFilesURL
{
    static NSURL *mm_iCloudLogFilesURL = nil;
    if( nil == mm_iCloudLogFilesURL ){
        
        NSURL *result = [self containerURL];
        
        result =
        [result URLByAppendingPathComponent: @"LogFiles"
                                isDirectory:YES];
        
        mm_iCloudLogFilesURL = [[result npNormalizedURL] copy];
        [self assureDirectoryURLExists: mm_iCloudLogFilesURL];
        
    }
    return mm_iCloudLogFilesURL;
}
+ (BOOL)isCloudEnabled {
    
    return [self containerURL] != nil;
    
}

+ (NSURL*)localDocsURL {
        
    static NSURL *mm_localDocsURL = nil;
    
    if( nil == mm_localDocsURL ){
        //    dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSFileManager *fileManager = [self fileManager];
        
        mm_localDocsURL =
        [[fileManager URLForDirectory:NSDocumentDirectory
                             inDomain:NSUserDomainMask
                    appropriateForURL:nil
                               create:NO
                                error:nil] npNormalizedURL];
        
        NSError *error = nil;
        BOOL ok =
        [fileManager createDirectoryAtURL: mm_localDocsURL
              withIntermediateDirectories: YES
                               attributes: nil
                                    error: &error];
        
        NSLog(@"-localDocsURL = %@", [mm_localDocsURL absoluteString]);
        
        if(!ok){
            NSLog(@"Dang!");
            NSLog(@"error = %@", [error description] );
        }
        
        [self assureDirectoryURLExists:mm_localDocsURL];
    }
    
    return mm_localDocsURL;
}

+(NSURL*)localDocURLForFileName: (NSString*)fileName
                           uuid: (NSString*)uuid
{
    
    NSURL *localDocsURL = [self localDocsURL];
    [self assureDirectoryURLExists: localDocsURL]; // just checking...
    
    NSURL *uuidDir = [localDocsURL URLByAppendingPathComponent: uuid
                                                   isDirectory:YES];
    
    [self assureDirectoryURLExists: uuidDir]; // the uuid dir
    
    NSURL *localDocURL = [uuidDir URLByAppendingPathComponent: fileName];
    return [localDocURL npNormalizedURL];
}

+(NSURL*)cloudDocURLForFileName: (NSString*)fileName
                           uuid: (NSString*)uuid
{
    if( ![self isCloudEnabled] ) return nil;
    
    NSURL* cloudDocUuidDir =
    [[self iCloudDocumentsURL] URLByAppendingPathComponent: uuid
                                               isDirectory: YES];
    
    [self assureDirectoryURLExists: cloudDocUuidDir]; // the uuid dir
    
    NSURL* cloudDocURL =
    [cloudDocUuidDir URLByAppendingPathComponent: fileName
                                     isDirectory: YES];
    return [cloudDocURL npNormalizedURL];
}

+(BOOL)isCloudURL: (NSURL*)url
{
    NSURL *cloudContainer = [self containerURL];
    if( nil == cloudContainer ) return NO;
    
    NSString *pathString = url.absoluteString;
    NSString *cloudContainerString = cloudContainer.absoluteString;
    
    return [pathString hasPrefix: cloudContainerString];
}

+(NSURL*)sandboxDirPathforCopyOfCloudContainerDir
{
    NSURL *appDocumentsDir = [self localDocsURL]; // the sandbox container
    // e.g.,
    // file://localhost/var/mobile/Applications/96AB74BA-3380-4CDD-BC6D-2EF7E2EF340B/Documents/
    
    NSURL *target = [appDocumentsDir URLByAppendingPathComponent: @"copyOfCloudContainer"];
    
    target = [[target URLByAppendingPathComponent: [[self containerURL] lastPathComponent]] npNormalizedURL];
    
    // e.g.,
    // file://localhost/var/mobile/Applications/96AB74BA-3380-4CDD-BC6D-2EF7E2EF340B/Documents/copyOfCloudContainer/TEAMCODE10~com~myCompany~MyApp/

    return target;
}


+(NSURL*)destSubURLFromSourceSubURL: (NSURL*)sourceSubURL
                   inCloudSourceDir:(NSURL *)srcDirURL
               forSandboxDestDirURL:(NSURL *)dstDirURL
{
    // Given:
    // sourceSubURL =
    // file://<srcDirURL>/<blah>/<blah'>/<foo>
    //
    // destSubURL =
    // file://<dstDirURL>/<blah>/<blah'>/<foo>
    //
    // returns destSubURL
    
    NSString *srcDirPathString =    srcDirURL.absoluteString;
    NSAssert( srcDirPathString.length, @"Bogus inSourceDir");
    
    NSString *srcSubPathString = sourceSubURL.absoluteString;
    NSAssert( srcSubPathString.length, @"Bogus SourceSubURL:");
    
    // [1] Make sure that sourceSubURL is contained in srcDirURL:
    NSRange range = [srcSubPathString rangeOfString:srcDirPathString];
    BOOL isSubDir = (range.length == srcDirPathString.length );
    NSAssert( isSubDir, @"Bogus subdirectory");
    
    // [2] copy
    
    NSArray *commonLeadingComponents = [srcDirURL pathComponents];
    NSMutableArray *trailingSubComponents   = [sourceSubURL pathComponents].mutableCopy;
    NSRange commonLeadingRange = NSMakeRange(0, commonLeadingComponents.count);
    [trailingSubComponents removeObjectsInRange: commonLeadingRange];
    
    NSMutableArray *tmp = dstDirURL.pathComponents.mutableCopy; // clear but inefficient
    [tmp addObjectsFromArray:trailingSubComponents];
    
    NSURL *result = [[NSURL fileURLWithPathComponents: tmp] npNormalizedURL];
    return result;
}

/**
 The -copyCloudContainerToSandbox method is for the development phase only.
 It's useful for bug reports and developer technical incidents.
 */
+(void)copyCloudContainerToSandbox
{
    /**
     
     See: http://colonelpanic.net/2012/01/ios-and-icloud-overcoming-bad-file-descriptor-errors/
     
     The method must step around ubiquitous files that haven't been downloaded yet.
     */
    NSURL __block *sandoxDestDirURL = [self sandboxDirPathforCopyOfCloudContainerDir];
    
    NSFileManager __block *fm = [NSFileManager defaultManager];
    NSError *error = nil;
    
    [self assureDirectoryURLExists: sandoxDestDirURL];
    [fm removeItemAtURL: sandoxDestDirURL
                  error: &error];
    [self assureDirectoryURLExists: [sandoxDestDirURL URLByDeletingLastPathComponent]];
    
    
    NSFileCoordinator *fc = [[NSFileCoordinator alloc] initWithFilePresenter: nil];
    
    [fc coordinateReadingItemAtURL: [self containerURL]
                           options: NSFileCoordinatorReadingWithoutChanges
                             error: &error
                        byAccessor:^(NSURL *coordinatedSrcURL) {
                            
                            NSArray *justOneKey = @[NSURLUbiquitousItemDownloadingStatusKey];
                            
                            NSDirectoryEnumerator *dirEnum =
                            [fm enumeratorAtURL:coordinatedSrcURL
                     includingPropertiesForKeys:justOneKey
                                        options: 0
                                   errorHandler: nil];
                            
                            NSError *mergeError = nil;
                            NSURL *sourceFileURL = nil;
                            
                            while ((sourceFileURL = [dirEnum nextObject])) {
                                // Directory or file URL?
                                
                                BOOL isDir = NO;
                                BOOL exists = [fm fileExistsAtPath: sourceFileURL.path
                                                       isDirectory: &isDir];
                                
                                // We must test on "exists".
                                // Sometimes, the enumerator's nextObject doesn't exist.
                                
                                if( exists ){
                                    NSURL *destFileURL =
                                    [self destSubURLFromSourceSubURL: [sourceFileURL npNormalizedURL]
                                                    inCloudSourceDir: [coordinatedSrcURL npNormalizedURL]
                                                forSandboxDestDirURL: [sandoxDestDirURL npNormalizedURL]];
                                    
                                    if( isDir ){
                                        [self assureDirectoryURLExists:destFileURL];
                                        
                                    }else{
                                        // By default, assume all files are able to be copied.
                                        NSString *downloadingStatus = @"?";
                                        
                                        // However, ubiquitous items that are not downloaded CANNOT be copied
                                        if ([fm isUbiquitousItemAtURL:sourceFileURL]) {
                                            [sourceFileURL getResourceValue:&downloadingStatus
                                                                     forKey:NSURLUbiquitousItemDownloadingStatusKey
                                                                      error:nil];
                                        }
                                        
                                        // Now copy the file if we can.
                                        NSArray *okDownloadingValues =
                                        @[NSURLUbiquitousItemDownloadingStatusCurrent, NSURLUbiquitousItemDownloadingStatusDownloaded];
                                        
                                        if ( [okDownloadingValues containsObject: downloadingStatus] ) {
                                            
                                            
                                            if (![fm copyItemAtURL:sourceFileURL
                                                             toURL:destFileURL
                                                             error:&mergeError]) {
                                                NSLog(@"ERROR (copy error): %@ -> %@ - %@", sourceFileURL, destFileURL, mergeError);
                                            }
                                        }                            }
                                    
                                }
                                
                            }
                            
                        }];
    
}
@end
