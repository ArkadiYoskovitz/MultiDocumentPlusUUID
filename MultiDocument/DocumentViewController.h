//
//  MDCDDetailViewController.h
//  MultiDocument
//
//
// This version of MultiDocument derives from Rich Warren's work.
// See: http://www.freelancemadscience.com/fmslabs_blog/2011/12/19/syncing-multiple-core-data-documents-using-icloud.html
//
//  Modified by Don Briggs on 2013 March 22.
//  Copyright (c) 2013.
//

#import <UIKit/UIKit.h>
@class NSFetchRequest;
@class TextEntry;

@interface DocumentViewController : UIViewController
<UITextViewDelegate>
{
    NSMutableArray *m_notificationObservers;
}
@property (readonly, strong) UIManagedDocument* document;

@property (readonly, strong) NSFileManager *fileManager;
@property (readwrite, strong) NSMutableDictionary *record;

@property (strong, nonatomic) IBOutlet UITextField* documentTitleTextField;
@property (strong, nonatomic) IBOutlet UITextField* docStateTextField;
@property (strong, nonatomic) IBOutlet UITextView* textView;

@property (readonly, strong) NSFetchRequest  *fetchRequest;
@property (readonly, strong) NSArray *fetchedObjects;

@property (readonly, strong) TextEntry *fetchedTextEntry;

@property (readonly, assign) NSUInteger retryCount;


@end
