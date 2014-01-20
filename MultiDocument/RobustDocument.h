//
//  RobustDocument.h
//  MultiDocument
//
//  Created by Don Briggs on 9/20/13.
//  Copyright (c) 2014 Don Briggs. All rights reserved.
//

#import <UIKit/UIKit.h>

/**
 
 "Handling Errors
 To enable your app to observe and handle errors in saving and validating a managed document, you must subclass the UIManagedDocument class and override one or both of the following two inherited methods from the UIDocument class:
 
    -handleError:userInteractionPermitted:
    -finishedHandlingError:recovered:
 
 Overriding is required because, otherwise, the only information your app receives on error is the 
    UIDocumentStateChangedNotification 
 notification, which does not contain a userInfo dictionary and so does not convey specific error information."
 
 That's the sole motivation for the RobustDocument class.
 
 */
@interface RobustDocument : UIManagedDocument

@end


