//
//  TextEntry.h
//  MultiDocument
//
//
// This version of MultiDocument derives from Rich Warren's work.
// See: http://www.freelancemadscience.com/fmslabs_blog/2011/12/19/syncing-multiple-core-data-documents-using-icloud.html
//
//  Modified by Don Briggs on 2013 March 22.
//  Copyright (c) 2013.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface TextEntry : NSManagedObject

@property (nonatomic, retain) NSString * text;
@property (nonatomic, retain) NSString * title;
@property (strong, nonatomic) NSDate* modified;

@end
