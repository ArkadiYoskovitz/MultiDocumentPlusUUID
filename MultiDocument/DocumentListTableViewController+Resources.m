//
//  DocumentListTableViewController+Resources.m
//  MultiDocument
//
///
// This version of MultiDocument derives from Rich Warren's work.
// See: http://www.freelancemadscience.com/fmslabs_blog/2011/12/19/syncing-multiple-core-data-documents-using-icloud.html
//
//  Modified by Don Briggs on 2013 March 22.
//  Copyright (c) 2013.
//

#import "DocumentListTableViewController+Resources.h"


#import "NSURL+NPAssisting.h"

@implementation DocumentListTableViewController (Resources)

+(NSFileManager*)fileManager
{
    static NSFileManager *mm_fileManager = nil;
    if( nil == mm_fileManager ){
        mm_fileManager = [[NSFileManager alloc] init];
    }
    return mm_fileManager;
}

+(void)actuallyCreateDirectoryAtURL: (NSURL*)url
{
    
    NSError *error = nil;
    BOOL result = [[self fileManager] createDirectoryAtPath: url.path
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

    BOOL __block result = NO;
    BOOL isDir = NO;
    BOOL exists = [[self fileManager] fileExistsAtPath: url.path
                                         isDirectory: &isDir];
    if( exists && isDir ){
        NSLog(@"directory exists: %@", url.path);
        result = YES;
        
    }else{
        NSLog(@"directory does NOT exist, creating: %@", url.path);
                
        if( [self isCloudURL: url] ){
            
            NSFileCoordinator *fileCoordinator =
            [[NSFileCoordinator alloc] initWithFilePresenter:nil];
            
            NSString *lpc = [url lastPathComponent];
            NSURL *containingDirectory = [url URLByDeletingLastPathComponent];
            
            [fileCoordinator coordinateWritingItemAtURL:containingDirectory
                                                options:NSFileCoordinatorWritingForMerging
                                                  error:nil
                                             byAccessor:^(NSURL *coordinatedURL) {
                                                 NSURL *target = [coordinatedURL URLByAppendingPathComponent:lpc];
                                                 
                                                 [self actuallyCreateDirectoryAtURL:target];
                                             }];
            
        }else{
            [self actuallyCreateDirectoryAtURL: url];
        }
        
     }
    return result;
}

+ (NSURL*)containerURL {
    
    static NSURL *mm_containerURL = nil;
    
    if( nil == mm_containerURL ){
        
        NSDate *start = [[NSDate date] copy];
        
        static dispatch_once_t onceToken;
        
        dispatch_once(&onceToken, ^{
            
            NSFileManager *fileManager = [[NSFileManager alloc] init];
            mm_containerURL =
            [fileManager URLForUbiquityContainerIdentifier:nil];
            
            NSDate *complete = [NSDate date];
            
            NSTimeInterval dT =
            [complete timeIntervalSinceReferenceDate] -
            [start timeIntervalSinceReferenceDate];
            
            NSLog(@" latency for -[NSFileManager URLForUbiquityContainerIdentifier:] = %f", dT);
            // The lowest I've seen recently is about 0.2 sec.
            // The highest is about 3.3 sec.
            
            //[self clearCloudContainer];
        });
    }
    
    return mm_containerURL;
}


+ (NSURL *)iCloudDocumentsURL
{
    return [[self containerURL] URLByAppendingPathComponent:@"Documents"];
}

+ (NSURL *)iCloudLogFilesURL
{
    static NSURL *mm_logFilesURL = nil;
    if( nil == mm_logFilesURL ){
        
        NSURL *result = [[self containerURL] copy];
        
        result =
        [result URLByAppendingPathComponent: @"LogFiles"
                                isDirectory:YES];
        [self assureDirectoryURLExists: result];
        
        mm_logFilesURL = [result copy];
        
    }
    return mm_logFilesURL;
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
+(void)clearCloudContainer
{
    // Clear the container -- must be done inside a file coordinator
    NSFileCoordinator *fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
    [fileCoordinator coordinateWritingItemAtURL: [self containerURL]
                                        options:NSFileCoordinatorWritingForDeleting
                                          error:nil
                                     byAccessor:^(NSURL *coordinatedURL) {
                                         
                                         [[self fileManager] removeItemAtURL:coordinatedURL
                                                                       error:nil];
                                     }];
}

@end
