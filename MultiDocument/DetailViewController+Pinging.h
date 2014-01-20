//
//  DetailViewController+Pinging.h
//  MultiDocumentPlusUUID

//
// MultiDocumentPlusUUID derives from Rich Warren's MultiDocument example.
// See: http://www.freelancemadscience.com/fmslabs_blog/2011/12/19/syncing-multiple-core-data-documents-using-icloud.html
//
//  Modified by Don Briggs on 2013 March 22.
//  Copyright (c) 2014 Don Briggs. All rights reserved.
//
//


#import "DetailViewController.h"

/**
 See: -[DetailViewController observeDocument:].
 The "Enable Ping" setting enables this category.
 */
@interface DetailViewController (Pinging)

-(void)logLatency;
-(void)snoozeToPingAfterMostRecentUbiquitousContentChange;

@end
