//
//  NSURL+NPAssisting.m
//  MultiDocumentPlusUUID

//
// MultiDocumentPlusUUID derives from Rich Warren's MultiDocument example.
// See: http://www.freelancemadscience.com/fmslabs_blog/2011/12/19/syncing-multiple-core-data-documents-using-icloud.html
//
//  Modified by Don Briggs on 2013 March 22.
//  Copyright (c) 2014 Don Briggs. All rights reserved.
//

#import "NSURL+NPAssisting.h"


@implementation NSURL (NPAssisting)
-(NSURL*)npNormalizedURL
{
    // See: https://github.com/omnigroup/OmniGroup/blob/master/Frameworks/OmniUI/iPad/OUIDocumentPreview.m
    
    // Need consistency in NSURLs:
    //     /private/var/mobile/blah vs /var/mobile/blah
    
    NSURL *step1 = [self URLByResolvingSymlinksInPath];
    NSURL *step2 = [step1 URLByStandardizingPath];
    
//         Example:
//         npNormalizedURL:
//         /private/var/mobile/Applications/CB7B8FC9-8756-4123-B624-C0C510DC438A/Documents/4FF18CF9-1392-4250-B3EA-2518FAB42FD5/Untitled ->
//                 /var/mobile/Applications/CB7B8FC9-8756-4123-B624-C0C510DC438A/Documents/4FF18CF9-1392-4250-B3EA-2518FAB42FD5/Untitled ->
//                 /var/mobile/Applications/CB7B8FC9-8756-4123-B624-C0C510DC438A/Documents/4FF18CF9-1392-4250-B3EA-2518FAB42FD5/Untitled
//
    return step2;
}
@end


