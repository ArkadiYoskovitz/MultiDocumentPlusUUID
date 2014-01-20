//
//  NSDictionary+NPAssisting.h
//  MultiDocument
//
//  Created by Don Briggs on 1/15/14.
//  Copyright (c) 2014 Don Briggs. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString* NPLocalDocURLKey;
extern NSString* NPCloudDocURLKey;
extern NSString* NPCloudLogFilesURLKey;
extern NSString* NPUUIDKey;
extern NSString* NPStoreOptionsKey;

extern NSString* NPMetadataItemKey;
extern NSString* NPMetadataDictionaryKey;
extern NSString* NPFileNameKey;
extern NSString* NPDocumentKey;

extern NSString* NPMostRecentUpdateKey;

extern NSString* NPDocumentPscImportObserverKey;
extern NSString* NPDocumentStateChangedObserverKey;

@interface NSDictionary (NPAssisting)


-(BOOL)npCreatedLocally;
-(NSURL*)npTargetDocURL;

-(NSString*)npStatus;
-(BOOL)isDocumentViewable;
@end
