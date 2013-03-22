//
//  DocumentListTableViewController+Resources.h
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

/**
 See Erica Sadun's CloudHelper class.
 It's pretty much all class methods.
 */
@interface DocumentListTableViewController (Resources)

+(NSFileManager*)fileManager;
+(void)actuallyCreateDirectoryAtURL: (NSURL*)url;
+(BOOL)assureDirectoryURLExists: (NSURL*)url;

+ (NSURL*)containerURL;
+ (NSURL *)iCloudLogFilesURL;
+ (NSURL *)iCloudDocumentsURL;

+ (BOOL)isCloudEnabled;
+ (NSURL*)localDocsURL;

+(BOOL)isCloudURL: (NSURL*)url;

+(NSURL*)localDocURLForFileName: (NSString*)fileName
                           uuid: (NSString*)uuid;
+(NSURL*)cloudDocURLForFileName: (NSString*)fileName
                           uuid: (NSString*)uuid;

+(void)clearCloudContainer;
@end
