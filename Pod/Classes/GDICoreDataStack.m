//
//  GDICoreDataStack.m
//  GDICoreDataKit
//
//  Created by Grant Davis on 9/12/13.
//  Copyright (c) 2013 Grant Davis Interactive, LLC. All rights reserved.
//

#import "GDICoreDataStack.h"

NSString * const GDICoreDataStackDidRebuildDatabase = @"GDICoreDataStackDidRebuildDatabase";

@interface GDICoreDataStack ()

@property (copy, nonatomic) NSString *storeName;
@property (copy, nonatomic) NSString *seedPath;
@property (copy, nonatomic) NSString *configuration;
@property (strong, nonatomic) NSHashTable *contextHashTable;
@property (strong, nonatomic) NSManagedObjectModel* managedObjectModel;
@property (strong, nonatomic) NSManagedObjectContext* mainContext;

@end


@implementation GDICoreDataStack

#pragma mark - Public API


- (id)initWithStoreName:(NSString *)storeName seedName:(NSString *)seedName configuration:(NSString *)config
{
    if (self = [super init]) {
        _storeName = storeName;
        _seedPath = seedName != nil ? [[NSBundle mainBundle] pathForResource:seedName ofType:nil] : nil;
        _configuration = config;
        [self commonInit];
    }
    return self;
}


- (id)initWithManagedObjectModel:(NSManagedObjectModel *)model storeName:(NSString *)storeName seedName:(NSString *)seedName configuration:(NSString *)config
{
    if (self = [super init]) {
        _managedObjectModel = model;
        _storeName = storeName;
        _seedPath = seedName != nil ? [[NSBundle mainBundle] pathForResource:seedName ofType:nil] : nil;
        _configuration = config;
        [self commonInit];
    }
    return self;
}


- (void)commonInit
{
    _contextHashTable = [NSHashTable hashTableWithOptions:NSPointerFunctionsWeakMemory];
    _shouldRebuildDatabaseIfPersistentStoreSetupFails = YES;
    _mainContextMergePolicy = NSMergeByPropertyStoreTrumpMergePolicy;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(contextDidSave:) name:NSManagedObjectContextDidSaveNotification object:nil];
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (NSPersistentStoreCoordinator *)setupCoreDataStackWithOptions:(NSDictionary *)options completion:(void (^)(BOOL success, NSError *error))completion
{
    @synchronized(self) {
        NSError *error = nil;
        if (_seedPath) {
            NSString *storePath = [[[self applicationDocumentsDirectory] URLByAppendingPathComponent:_storeName] path];
            BOOL success = [self copySeedDatabaseIfNecessaryFromPath:_seedPath
                                                              toPath:storePath
                                                               error:&error];
            if (! success) {
                NSLog(@"Failed to copy seed database at path: %@", _seedPath);
                if (completion) {
                    completion(NO, error);
                }
                return nil;
            }
        }
        
        NSURL *storeURL = [self defaultStoreURL];
        
        // do not rebuild in case there are observers registered for this coordinator's events
        if (_persistentStoreCoordinator == nil) {
            _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
        }
        
        NSPersistentStore *store = [_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                                             configuration:_configuration
                                                                                       URL:storeURL
                                                                                   options:options
                                                                                     error:&error];
        if (store == nil && _shouldRebuildDatabaseIfPersistentStoreSetupFails) {
            NSLog(@"error opening persistent store, removing");
            
            error = nil;
            if (![[NSFileManager defaultManager] removeItemAtURL:storeURL error:&error]) {
                NSLog(@"error removing persistent store %@, giving up", storeURL);
            }
            else {
                store = [_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                                  configuration:_configuration
                                                                            URL:storeURL
                                                                        options:options
                                                                          error:&error];
                
                if (store != nil) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:GDICoreDataStackDidRebuildDatabase object:self];
                }
                else {
                    NSLog(@"error opening persistent store, giving up");
                }
            }
        }
        
        _mainContext = nil;
        _persistentStore = store;
        _ready = (_persistentStore != nil);
        
        if (completion) {
            completion(_ready, error);
        }
    }
    return _persistentStoreCoordinator;
}


- (NSPersistentStore *)migratePersistentStoreWithOptions:(NSDictionary *)options destinationStoreName:(NSString *)destinationStoreName error:(NSError **)error
{
    @synchronized(self) {
        NSURL *destinationURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:destinationStoreName];
        
        if (self.persistentStore == nil) {
            NSAssert(NO, @"Cannot migrate a nil store. Something must be terribly wrong.");
        }
        
        _persistentStore = [self.persistentStoreCoordinator migratePersistentStore:self.persistentStore toURL:destinationURL options:options withType:NSSQLiteStoreType error:error];
        
        _mainContext = nil;
        
        self.storeName = destinationStoreName;
        
        [self.contextHashTable removeAllObjects];
        
    }
    return _persistentStore;
}


- (BOOL)removePersistentStore
{
    BOOL success = NO;
    @synchronized(self) {
        if (_persistentStoreCoordinator != nil && _persistentStore != nil) {
            NSError *error = nil;
            success = [_persistentStoreCoordinator removePersistentStore:_persistentStore error:&error];
            
            if (success) {
                _mainContext = nil;
                _persistentStore = nil;
            }
            else {
                NSLog(@"⚠️ Encountered error removing persistent store: %@", error);
            }
        }
    }
    return success;
}


#pragma mark - Worker Methods


- (BOOL)copySeedDatabaseIfNecessaryFromPath:(NSString *)seedPath toPath:(NSString *)storePath error:(NSError **)error
{
    if (NO == [[NSFileManager defaultManager] fileExistsAtPath:storePath]) {
        NSError *localError;
        if (![[NSFileManager defaultManager] copyItemAtPath:seedPath toPath:storePath error:&localError]) {
            NSLog(@"⚠️ Failed to copy seed database from path '%@' to path '%@': %@", seedPath, storePath, [localError localizedDescription]);
            if (error) *error = localError;
            return NO;
        }
        NSLog(@"👍🏻 Successfully copied seed database!");
    }
    return YES;
}


#pragma mark - Context


- (NSManagedObjectContext *)createPrivateContext
{
    return [self createContextWithMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy
                              concurrencyType:NSPrivateQueueConcurrencyType];
}


- (NSManagedObjectContext *)createPrivateContextWithMergePolicy:(id)mergePolicy
{
    return [self createContextWithMergePolicy:mergePolicy
                              concurrencyType:NSPrivateQueueConcurrencyType];
}


- (NSManagedObjectContext *)createContextWithMergePolicy:(id)mergePolicy
                                         concurrencyType:(NSManagedObjectContextConcurrencyType)type
{
    NSManagedObjectContext *context;
    if (self.persistentStoreCoordinator != nil) {
        context = [[NSManagedObjectContext alloc] initWithConcurrencyType:type];
        context.persistentStoreCoordinator = self.persistentStoreCoordinator;
        context.mergePolicy = mergePolicy;
        context.undoManager = nil;
        
        @synchronized(self) {
            [self.contextHashTable addObject:context];
        }
    }
    return context;
}


- (void)contextDidSave:(NSNotification *)notification
{
    if ([notification.object isKindOfClass:[NSManagedObjectContext class]]) {
        NSManagedObjectContext *context = notification.object;
        @synchronized(self) {
            if ([self.contextHashTable containsObject:context]) {
                for (NSManagedObjectContext *savedContext in self.contextHashTable) {
                    if (savedContext != context) {
                        NSLog(@"🔥🔥🔥 Merging changes from context: %@", context);
                        [savedContext performBlockAndWait:^{
                            [savedContext mergeChangesFromContextDidSaveNotification:notification];
                        }];
                    }
                }
            }
        }
    }
}


#pragma mark - Accessors

- (void)setMainContextMergePolicy:(id)mainContextMergePolicy
{
    _mainContextMergePolicy = mainContextMergePolicy;
    
    if (self.mainContext != nil) {
        self.mainContext.mergePolicy = mainContextMergePolicy;
    }
}


- (NSURL *)defaultStoreURL
{
    return [[self applicationDocumentsDirectory] URLByAppendingPathComponent:_storeName];
}


- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel == nil) {
        _managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:nil];
    }
    return _managedObjectModel;
}


- (NSManagedObjectContext *)mainContext
{
    if (_mainContext == nil) {
        NSPersistentStoreCoordinator *coordinator = self.persistentStoreCoordinator;
        if (coordinator != nil) {
            _mainContext = [self createContextWithMergePolicy:self.mainContextMergePolicy
                                              concurrencyType:NSMainQueueConcurrencyType];
        }
    }
    return _mainContext;
}


/**
 Returns the URL to the application's Documents directory.
 */
- (NSURL *)applicationDocumentsDirectory
{
    NSArray *directories = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    return (directories.count > 0) ? [directories objectAtIndex:0] : nil;
}


@end
