//
//  DocumentsListController+Resources.h
//  MultiDocumentPlusUUID

//
//
// MultiDocumentPlusUUID derives from Rich Warren's MultiDocument example.
// See: http://www.freelancemadscience.com/fmslabs_blog/2011/12/19/syncing-multiple-core-data-documents-using-icloud.html
//
//  Modified by Don Briggs on 2013 March 22.
//  Copyright (c) 2014 Don Briggs. All rights reserved.
//

#import "DocumentsListController.h"

/**
 See Erica Sadun's CloudHelper class.
 It's pretty much all class methods.
 */
@interface DocumentsListController (Resources)

+(NSFileManager*)fileManager;
+(void)actuallyCreateDirectoryAtURL: (NSURL*)url;
+(BOOL)assureDirectoryURLExists: (NSURL*)url;

+(void)getContainerURLWithCallback: (NSInvocation*)callback;
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

/**
 The -copyCloudContainerToSandbox method is for the development phase only.
 It's useful for bug reports and developer technical incidents.
 */
+(void)copyCloudContainerToSandbox;

@end
