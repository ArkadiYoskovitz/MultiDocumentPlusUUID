//
//  UIDocument+NPExtending.m
//  MultiDocumentPlusUUID

//
//  Created by DevGuy on 7/15/13.
//  Copyright (c) 2013 Freelance Mad Science Labs. All rights reserved.
//

#import "UIDocument+NPExtending.h"

@implementation UIDocument (NPExtending)
-(NSString*)npDocumentStateAsString
{
    
    NSUInteger state = self.documentState;
    
    // It seems unfortunate that UIManagedDocumentStateNormal == 0.
    // 0 == [<nil> documentState];
    if (UIDocumentStateNormal == state) return @"[Normal]";
    
    NSMutableArray *words = [NSMutableArray arrayWithCapacity: 4];
    if ((state & UIDocumentStateClosed) != 0)
        [words addObject:@"Closed"];
    if ((state & UIDocumentStateInConflict) != 0)
        [words addObject:@"Conflict"];
    if ((state & UIDocumentStateSavingError) != 0)
        [words addObject:@"Saving Error"];
    if ((state & UIDocumentStateEditingDisabled) != 0)
        [words addObject:@"EditingDisabled" ];
    
    NSString *result =
    [NSString stringWithFormat:@"[%@]",
     [words componentsJoinedByString: @"|"] ];
    
    return result;
    
}
@end
