//
//  NSURL+NPAssisting.h
//  MultiDocumentPlusUUID
//
// MultiDocumentPlusUUID derives from Rich Warren's MultiDocument example.
// See: http://www.freelancemadscience.com/fmslabs_blog/2011/12/19/syncing-multiple-core-data-documents-using-icloud.html
//
//  Modified by Don Briggs on 2013 March 22.
//  Copyright (c) 2014 Don Briggs. All rights reserved.
//

#import <Foundation/Foundation.h>


/**
 Need consistency in NSURLs:
    /private/var/mobile/blah vs /var/mobile/blah 

 */
@interface NSURL (NPAssisting)
-(NSURL*)npNormalizedURL;
@end


