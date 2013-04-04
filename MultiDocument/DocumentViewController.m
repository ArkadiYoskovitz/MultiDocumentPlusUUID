//
//  MDCDDetailViewController.m
//  MultiDocument
//
// This version of MultiDocument derives from Rich Warren's work.
// See: http://www.freelancemadscience.com/fmslabs_blog/2011/12/19/syncing-multiple-core-data-documents-using-icloud.html
//
//  Modified by Don Briggs on 2013 March 22.
//  Copyright (c) 2013.
//


#import "DocumentViewController.h"
#import "DocumentViewController+Pinging.h"

#import "DocumentListTableViewController+Resources.h"
#import "DocumentListTableViewController+Making.h"


#import "TextEntry.h"

#import "DocumentListTableViewController.h" // Get the keys for the record

#import "NSURL+NPAssisting.h"

@interface DocumentViewController()

@property (readonly, strong) NSMutableArray* notificationObservers;
@property (readwrite, strong) UIManagedDocument *document;

@property (readonly, strong) NSURL *localDocURL;
@property (readonly, strong) NSURL *cloudDocURL;
@property (readonly, strong) NSString *fileName;
@property (readonly, strong) NSDictionary *storeOptions;
@property (readonly, strong) NSString *uuid;
@property (readonly, strong) NSDictionary *metadata;

@property (readwrite, assign) NSUInteger retryCount;

@end

@implementation DocumentViewController

@synthesize documentTitleTextField = _documentTitle;
@synthesize docStateTextField = _docStateTextField;
@synthesize textView = _text;

@dynamic notificationObservers;

@synthesize retryCount;

@dynamic localDocURL;
@dynamic cloudDocURL;
@dynamic fileName;
@dynamic storeOptions;
@dynamic uuid;
@dynamic metadata;

-(UIManagedDocument*)document
{
    return [self.record objectForKey: NPDocumentKey];
}
-(void)setDocument:(UIManagedDocument *)aDocument
{
    [self ignoreDocument];{
        
        [self.record removeObjectForKey: NPDocumentKey];
        
        [self.record setObject: aDocument
                        forKey:NPDocumentKey];

    }[self observeDocument];
}

-(NSFileManager*)fileManager
{
    return [DocumentListTableViewController fileManager];
}
#pragma mark Convenience accessors for items stored in self.record
-(NSURL*)localDocURL
{
    return [self.record objectForKey: NPLocalURLKey];
}
-(NSURL*)cloudDocURL
{
    return [self.record objectForKey: NPCloudURLKey];
}
-(NSString*)fileName
{
    return [self.record objectForKey: NPFileNameKey];
}
-(NSDictionary*)storeOptions
{
    return [self.record objectForKey: NPStoreOptionsKey];
}
-(NSString*)uuid
{
    return [self.record objectForKey: NPUUIDKey];
}
-(NSDictionary*)metadata
{
    return [self.record objectForKey: NPMetadataDictionaryKey];
}

+(NSArray*)fetchResultsSortDescriptors
{
    return [NSArray array];
}

-(NSArray*)fetchedObjectsFromMocFetchRequest
{
    NSManagedObjectContext *moc = [self.document managedObjectContext];
    NSFetchRequest *frq = self.fetchRequest;
    
    if( nil == frq ) return [NSArray array];
    
    NSError *error = nil;
    // GLITCH: moc has no registered objects.
    // The following call triggers -mocObjectsDidChange:
    NSArray *result = [moc executeFetchRequest: frq
                                         error: &error];
    if( error ){
        NSLog(@"-[NSManagedObjectContext executeFetchRequest:error:] Unresolved error %@, %@",
              error, [error userInfo]);
        exit(-1);  // Fail
        
    }
    
    return result;
}
+(NSString*)entityName
{
    return @"TextEntry";
}

-(NSFetchRequest*)fetchRequest
{
    NSFetchRequest *result = nil;
    NSManagedObjectContext *moc = [self.document managedObjectContext];
    
    NSString *entityName = [[self class] entityName];
    NSEntityDescription *entity = [NSEntityDescription entityForName:entityName
                                              inManagedObjectContext:moc];
    NSArray *sortDescriptors = [[self class] fetchResultsSortDescriptors];
    
    result = [[NSFetchRequest alloc] init];
    [result setEntity:entity];
    [result setSortDescriptors:sortDescriptors];
    return result;
}

-(NSArray*)fetchedObjects
{
    NSArray *result = nil;
    
    if( nil == self.document ){
        result = [NSArray array];
    }else{
        result = [self fetchedObjectsFromMocFetchRequest];
    }
    
    return result;
}
-(TextEntry*)fetchedTextEntry
{
    TextEntry *result = nil;
    NSArray *fObjs = [self fetchedObjects];
    
    switch ( fObjs.count ) {
        case 0:
        {
            break;
        }
        case 1:
        {
            result = [fObjs lastObject];
            break;
        }
        default:
        {
            NSAssert( NO, @"Bogus count of fetched objects = %d", fObjs.count);
            break;
        }
    }
    return result;
}
-(NSMutableArray*)notificationObservers
{
    if( nil == m_notificationObservers ){
        m_notificationObservers = [[NSMutableArray alloc] initWithCapacity: 4];
    }
    return m_notificationObservers;
}

-(void)updateFromCloud
{
    NSLog(@"%@: -updateFromCloud BEGIN",
          [[UIDevice currentDevice] model] );

    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    NSRunLoop *mainRunLoop = [NSRunLoop mainRunLoop];
    NSAssert( (mainRunLoop == runLoop), @"Not main run loop.");
    
    [runLoop cancelPerformSelector: @selector(updateFromCloud)
                            target: self
                          argument: nil];
    
    [self setViewFromModel];
         
    NSArray *modes = [NSArray arrayWithObject: NSDefaultRunLoopMode];
    [runLoop performSelector: @selector(schedulePing)
                      target: self
                    argument: nil
                       order: 5
                       modes: modes];
    
    
    NSLog(@"%@: -updateFromCloud END",
          [[UIDevice currentDevice] model] );
}
-(void)scheduleUpdateFromCloud
{
    NSRunLoop *runLoop = [NSRunLoop mainRunLoop]; 
    
    NSArray *modes = [NSArray arrayWithObject: NSDefaultRunLoopMode];
    [runLoop performSelector:@selector(updateFromCloud)
                      target:self
                    argument: nil
                       order: 5
                       modes: modes];
    
}

-(void)observeDocument
{
    NSNotificationCenter* center =
    [NSNotificationCenter defaultCenter];
    
    
    NSPersistentStoreCoordinator *psc =
    self.document.managedObjectContext.persistentStoreCoordinator;
    
    id observer =
    [center addObserverForName:NSPersistentStoreDidImportUbiquitousContentChangesNotification
                        object:psc
                         queue:nil
                    usingBlock:^(NSNotification *note) {
                        
                        
                        NSLog(@"%@: NSPersistentStoreDidImportUbiquitousContentChangesNotification: Merging changes",
                              [[UIDevice currentDevice] model] );
                        
                        NSLog(@"%@: Updating content from iCloud",
                              [[UIDevice currentDevice] model] );
                        
                        NSManagedObjectContext* moc =
                        self.document.managedObjectContext;
                        [moc performBlockAndWait:^{
                            
                            NSUndoManager * undoManager = [moc undoManager];
                            [undoManager disableUndoRegistration];{
                                [moc mergeChangesFromContextDidSaveNotification:note];
                                [moc processPendingChanges];
                            }[undoManager enableUndoRegistration];

                        }];
                        
                        [self scheduleUpdateFromCloud];

                    }];
    [self.notificationObservers addObject:observer];
    
    observer =
    [center addObserverForName:UIDocumentStateChangedNotification
                        object:self.document
                         queue:nil
                    usingBlock:^(NSNotification *note) {
                        
                        UIDocumentState state = self.document.documentState;
                        
                        NSLog(@"%@: UIDocumentStateChangedNotification:",
                              [[UIDevice currentDevice] model]);
                        
                        NSString *docStateText = [self documentStateAsString];
                        NSLog(@"    %@", docStateText);
                        
                        if (state == UIDocumentStateNormal) {
                            self.retryCount = 0;
                            NSLog(@"    self.retryCount = 0 ");
                        }else{
                            self.textView.backgroundColor = [UIColor lightGrayColor];
                        }

                        [self setViewFromModel];

                    }];
    [self.notificationObservers addObject:observer];
    
    observer =
    [center addObserverForName:NSManagedObjectContextObjectsDidChangeNotification
                        object:self.document.managedObjectContext
                         queue:nil
                    usingBlock:^(NSNotification *note) {
                        
                        NSLog(@"%@: NSManagedObjectContextObjectsDidChangeNotification",
                              [[UIDevice currentDevice] model]);
                        
                        [self setViewFromModel];
                        
                    }];
    [self.notificationObservers addObject:observer];
}

-(void)ignoreDocument
{
    for (id observer in self.notificationObservers) {
        [[NSNotificationCenter defaultCenter]
         removeObserver:observer];
    }
    [self.notificationObservers removeAllObjects];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.retryCount = 0;
    
    if( nil == self.document ){
        NSLog( @"no document");
        NSAssert( NO, @"no document");
    }else{
        [self observeDocument];
    }
    
    self.textView.delegate = self;
    self.textView.keyboardType = UIKeyboardTypeDefault;
    self.textView.returnKeyType = UIReturnKeyDone;
    
    self.docStateTextField.enabled = NO;
    self.documentTitleTextField.enabled = NO;
    
    [self setViewFromModel];
    
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

#pragma mark - Show Document

-(BOOL)anyUnsavedChanges
{
    TextEntry *textEntry = [self fetchedTextEntry];
    
    if( nil == textEntry ) return NO;
    
    NSString *modelText = textEntry.text;
    NSString *uiText = self.textView.text;
    return  ![modelText isEqualToString: uiText];
}

-(void)setViewFromModel
{
    if( UIDocumentStateNormal == self.document.documentState){
        self.retryCount = 0;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        
        TextEntry *textEntry = [self fetchedTextEntry];
        
        NSString *modSuffix = @"??";
        self.documentTitleTextField.text = self.document.localizedName;
        
        NSString *docStateText = [self documentStateAsString];
        
        if( nil == textEntry ){
            self.textView.text = @"<nil>";
            self.docStateTextField.text = @"!!";
        }else{
            self.textView.text = textEntry.text;
            modSuffix =[(textEntry.modified) description];
        }
        
        self.docStateTextField.text =
        [NSString stringWithFormat: @"%@, %@",
         docStateText,
         modSuffix];
        
        [(self.documentTitleTextField) setNeedsDisplay];
        [(self.docStateTextField)      setNeedsDisplay];
        [(self.textView)               setNeedsDisplay];
        
        NSLog(@"%@: -setViewFromModel at %@",
              [[UIDevice currentDevice] model],
              [[NSDate date] description]);

        
    });
}
-(void)setModelFromView
{
    TextEntry *textEntryOuter = [self fetchedTextEntry];
    
    if( nil == textEntryOuter ) return;
    
    if( [self anyUnsavedChanges] ){
        
        NSManagedObjectContext *moc = self.document.managedObjectContext;
        
        [moc performBlockAndWait: ^{
            
            TextEntry *textEntry = [self fetchedTextEntry];
            
            NSLog(@"%@: -setModelFromView (changes) at %@",
                  [[UIDevice currentDevice] model],
                  [[NSDate date] description]);
            
            textEntry.text = self.textView.text;
            textEntry.modified = [NSDate date];
            
            [moc processPendingChanges];
            
        }]; //[moc performBlockAndWait:
        
    } //if( [self anyUnsavedChanges] )
    
}
-(NSString *) documentStateAsString
{
    if( nil == self.document ) return @"<nil>";

    NSUInteger state = self.document.documentState;
    
    // It seems unfortunate that UIManagedDocumentStateNormal == 0.
    // 0 == [<nil> documentState];
    if (UIDocumentStateNormal == state) return @"Normal";
    
    NSMutableArray *words = [NSMutableArray arrayWithCapacity: 4];
    if ((state & UIDocumentStateClosed) != 0)
        [words addObject:@"Closed"];
    if ((state & UIDocumentStateInConflict) != 0)
        [words addObject:@"Conflict"];
    if ((state & UIDocumentStateSavingError) != 0)
        [words addObject:@"Saving Error"];
    if ((state & UIDocumentStateEditingDisabled) != 0)
        [words addObject:@"Disabled" ];
    
    NSString *result = [words componentsJoinedByString: @"|"];
    return result;
    
}

#pragma mark UITextViewDelegate for self.text
-(void)finishEditing
{
    [(self.textView) resignFirstResponder];
    [self setModelFromView];
}
- (void)textViewDidEndEditing:(UITextView *)aTextView
{
    [self finishEditing];
}
- (BOOL)       textView: (UITextView*) textView
shouldChangeTextInRange: (NSRange) range
        replacementText: (NSString*) text
{
    if ([text isEqualToString:@"\n"]) {
        [self finishEditing];
        return NO;
    }else{
        return YES;
    }
}
@end
