//
//  DocumentCell.h
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

@interface DocumentCell : UITableViewCell
@property (strong, nonatomic) IBOutlet UILabel* fileNameUILabel;
@end
