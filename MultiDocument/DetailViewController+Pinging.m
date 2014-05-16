//
//  DetailViewController+Pinging.m
//  MultiDocumentPlusUUID

//
//
// MultiDocumentPlusUUID derives from Rich Warren's MultiDocument example.
// See: http://www.freelancemadscience.com/fmslabs_blog/2011/12/19/syncing-multiple-core-data-documents-using-icloud.html
//
//  Modified by Don Briggs on 2013 March 22.
//  Copyright (c) 2014 Don Briggs. All rights reserved.
//

#import "DetailViewController+Pinging.h"
#import "TextEntry.h"

NSString *NPCloudSyncLatencies = @"Cloud Sync Latencies";
NSString *NPPingEnabledKey = @"pingEnabled";

@implementation DetailViewController (Pinging)

// For some reason, the cloud updates sometimes come in bursts.
// We want one responding ping for each burst, not a ping for each update.
NSTimeInterval mm_snoozeInterval = 1.0; // Wait a short bit after the most recent cloud update to fire the responding ping.

/**
    This method imposes some "hysteresis" on the responding ping. The cloud updates sometimes come in bursts. This method provides one responding ping after each burst of updates, not a ping for each update.

 */
-(void)snoozeToPingAfterMostRecentUbiquitousContentChange
{
    /*
     "-[NSTimer invalidate] Stops the receiver from ever firing again and requests its removal from its run loop."
     */
    [m_pingTimer invalidate];
    m_pingTimer = nil;
    
    NSRunLoop *main = [NSRunLoop mainRunLoop];
    
    m_pingTimer = [NSTimer timerWithTimeInterval: mm_snoozeInterval
                                          target: self
                                        selector: @selector(ping:) // -ping: invalidates and nullifies m_pingTimer.
                                        userInfo: nil
                                         repeats: NO];
    
    [main addTimer: m_pingTimer
           forMode: NSDefaultRunLoopMode];

}
-(void)clearLatencies
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults removeObjectForKey: NPCloudSyncLatencies];
    [userDefaults synchronize];
}

/**
 Adds the discovered latency (current time - time of remote modification) to an array in user defaults.
 */
-(void)logPscImportLatency
{
    NSDate *now = [NSDate date];
    TextEntry *textEntry = [self fetchedTextEntry];
    NSDate *then = textEntry.modified;
    
    NSTimeInterval dT =
    now.timeIntervalSinceReferenceDate -
    then.timeIntervalSinceReferenceDate;
    
    NSNumber *latency = @(dT);
    
    NSString *key = NPCloudSyncLatencies;
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults synchronize];{
        
        NSMutableArray *latencies =
        [[userDefaults objectForKey: key] mutableCopy];
        if( nil == latencies ){
            latencies = [NSMutableArray arrayWithCapacity:1];
        }
        [latencies addObject: latency];
        [userDefaults setObject: [latencies copy]
                         forKey: key];

    }[userDefaults synchronize];

    return;
}

/**
 Generates a string of successive recorded latencies, suitable for pasting into a desktop spreadsheet app (e.g., Numbers).
 
 @return a string of successive recorded latencies, one number per line.
 */
-(NSString*)latenciesAsString
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults synchronize];
    
    NSArray *latencies = [userDefaults objectForKey: NPCloudSyncLatencies];
    
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
-(void)ping:(NSTimer *)timer
{
    NSLog(@"%@: -ping: BEGIN",
          [[UIDevice currentDevice] model] );
    
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    NSRunLoop *mainRunLoop = [NSRunLoop mainRunLoop];
    NSAssert( (mainRunLoop == runLoop), @"Not main run loop.");

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults synchronize];
    
    BOOL pingEnabled = [userDefaults boolForKey:NPPingEnabledKey];
    
    NSLog(@"pingEnabled = %@", pingEnabled ? @"YES" : @"NO" );
    
    if( pingEnabled ) {
        
        if( [timer isValid] ){
            
            [self readModelWriteView];{
                
                UIDevice *device = [UIDevice currentDevice];
                
                NSString *blargSpaceDeviceName =
                [NSString stringWithFormat: @"%@ %@ pings",
                 self.textView.text,
                 device.name];
                
                self.textView.text = blargSpaceDeviceName.copy;

            }[self readViewWriteModel]; // Also updates TextEntry.modified.
    
            
        };
        
    }
    
    [timer invalidate];
    [m_pingTimer invalidate];
    m_pingTimer = nil;
    
    NSLog(@"%@: -ping: END",
          [[UIDevice currentDevice] model] );
    
}


@end
