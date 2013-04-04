//
//  DocumentViewController+Pinging.m
//  MultiDocument
//
//
// This version of MultiDocument derives from Rich Warren's work.
// See: http://www.freelancemadscience.com/fmslabs_blog/2011/12/19/syncing-multiple-core-data-documents-using-icloud.html
//
//  Modified by Don Briggs on 2013 March 22.
//  Copyright (c) 2013.
//

#import "DocumentViewController+Pinging.h"
#import "TextEntry.h"

NSString *NPTextEntryLatencies = @"TextEntry Latencies across Devices";

@implementation DocumentViewController (Pinging)

-(void)clearLatencies
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults removeObjectForKey: NPTextEntryLatencies];
}
-(void)logLatency
{
    NSDate *now = [NSDate date];
    TextEntry *textEntry = [self fetchedTextEntry];
    NSDate *then = textEntry.modified;
    
    NSTimeInterval dT =
    now.timeIntervalSinceReferenceDate -
    then.timeIntervalSinceReferenceDate;
    
    NSNumber *latency = [NSNumber numberWithDouble: dT];
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    NSMutableArray *latencies = [[userDefaults objectForKey: NPTextEntryLatencies] mutableCopy];
    if( nil == latencies ){
        latencies = [NSMutableArray arrayWithCapacity:1];
    }
    [latencies addObject: latency];
    [userDefaults setObject: [latencies copy]
                     forKey:NPTextEntryLatencies];
    return ;
    
}
-(NSString*)latenciesAsString
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    NSArray *latencies = [userDefaults objectForKey: NPTextEntryLatencies];
    
    NSMutableString *report = [NSMutableString stringWithCapacity: 128];
    for( NSNumber *n in latencies ){
        [report appendFormat: @"%@\n", [n stringValue]];
    }
    return report;
}
-(void)reportLatencies
{
    NSString *report = [self latenciesAsString];
    NSLog(@"%@", report);
}
-(void)ping
{
    NSLog(@"%@: -ping BEGIN",
          [[UIDevice currentDevice] model] );

    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    NSRunLoop *mainRunLoop = [NSRunLoop mainRunLoop];
    
    NSAssert( (mainRunLoop == runLoop), @"Not main run loop.");
    
    [runLoop cancelPerformSelector: @selector(ping)
                            target: self
                          argument: nil];

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    BOOL pingEnabled = [userDefaults boolForKey: @"pingEnabled"];
    
    if( !pingEnabled ) return;
    
   
//    dispatch_async(dispatch_get_main_queue(), ^{
        
        [self logLatency];
        
        TextEntry *textEntry = [self fetchedTextEntry];
        UIDevice *device = [UIDevice currentDevice];
        
        NSString *blargSpaceDeviceName = [NSString stringWithFormat: @"%@ %@ pings",
                                          textEntry.text,
                                          device.name];
        
        textEntry.text = blargSpaceDeviceName;
        textEntry.modified = [NSDate date];
        
        // Use performSelector: to avoid declaring or making -setViewFromModel public.
        [self performSelector: @selector(setViewFromModel)];
        
//    });
    NSLog(@"%@: -ping END",
          [[UIDevice currentDevice] model] );

}

-(void)schedulePing
{
    NSLog(@"%@: -schedulePing BEGIN",
          [[UIDevice currentDevice] model] );
    
    NSRunLoop *runLoop = [NSRunLoop mainRunLoop]; //[NSRunLoop currentRunLoop];
    
    NSArray *modes = [NSArray arrayWithObject: NSDefaultRunLoopMode];
    [runLoop performSelector:@selector(ping)
                      target:self
                    argument: nil
                       order: 10
                       modes: modes];
    
    NSLog(@"%@: -schedulePing END",
          [[UIDevice currentDevice] model] );

    
}

@end
