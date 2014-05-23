//
//  NSDictionary+NPAssisting.h
//  MultiDocument
//
//  Created by Don Briggs on 1/15/14.
//  Copyright (c) 2014 Don Briggs. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *NPDocumentMetadataDotPlist;

extern NSString* NPLocalDocURLKey;
extern NSString* NPCloudDocURLKey;

extern NSString* NPLocalDocumentMetadataPlistURLKey;
extern NSString* NPCloudDocumentMetadataPlistURLKey;

extern NSString* NPCloudLogFilesURLKey;
extern NSString* NPUUIDKey;



extern NSString* NPLocalStoreOptionsKey;
extern NSString* NPCloudStoreOptionsKey;

extern NSString* NPSuccessCallbackKey;
extern NSString* NPFailureCallbackKey;


extern NSString* NPMetadataItemKey;
extern NSString* NPMetadataDictionaryKey;
extern NSString* NPFileNameKey;
extern NSString* NPDocumentKey;

extern NSString* NPNotificationDates;
extern NSString* NPStealthyDidFinishImport;

extern NSString* NPDocumentPscImportObserverKey;
extern NSString* NPDocumentStealthyImportObserverKey;

extern NSString* NPDocumentPscStoresWillChangeObserverKey;
extern NSString* NPDocumentPscStoresDidChangeObserverKey;

extern NSString* NPDocumentStateChangedObserverKey;
extern NSString* NPDocumentMocObjectsChangedObserverKey;


@interface NSDictionary (NPAssisting)


-(BOOL)npCreatedLocally;
-(NSURL*)npTargetDocURL;

-(NSString*)npStatus;
-(BOOL)isDocumentViewable;

@end
