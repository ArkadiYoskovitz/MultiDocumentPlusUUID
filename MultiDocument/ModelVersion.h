//
//  ModelVersion.h
//  MultiDocumentPlusUUID

//
//
// MultiDocumentPlusUUID derives from Rich Warren's MultiDocument example.
// See: http://www.freelancemadscience.com/fmslabs_blog/2011/12/19/syncing-multiple-core-data-documents-using-icloud.html
//
//  Modified by Don Briggs on 2013 March 22.
//  Copyright (c) 2013.
//

#import <CoreData/CoreData.h>

@interface ModelVersion : NSManagedObject

@property (nonatomic, retain) NSNumber * versionNumber;

+(NSNumber*)currentVersionNumber;
@end
