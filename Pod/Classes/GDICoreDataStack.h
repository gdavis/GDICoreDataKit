//
//  GDICoreDataStack.h
//  GDICoreDataKit
//
//  Created by Grant Davis on 9/12/13.
//  Copyright (c) 2014 Grant Davis Interactive, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


extern NSString * const GDICoreDataStackDidRebuildDatabase;


@interface GDICoreDataStack : NSObject


/**
 *  Main CoreData stack properties
 *  TODO: finish documentation for each
 */
@property (readonly, copy, nonatomic) NSString *storeName;
@property (readonly, strong, nonatomic) NSManagedObjectContext *mainContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStore *persistentStore;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (readonly, strong, nonatomic) NSHashTable *contextHashTable;
@property (nonatomic, readonly, getter=isReady) BOOL ready;
@property (assign, nonatomic) id mainContextMergePolicy;

/**
 *  If the setupCoreDataStackWithCompletion method fails during its first attempt to add the
 *  persistent store to the coordinator, the system will attempt to remove the existing database file
 *  and create a new one. Defaults to YES.
 */
@property (nonatomic) BOOL shouldRebuildDatabaseIfPersistentStoreSetupFails;


/**
 *  Initializes a new instance. The CoreData stack is not yet available after instantiating this object
 *  and needs to be created with the `setupCoreDataStackWithCompletion:` method. If a seed database name
 *  is provided, this class will attempt to make a copy of that seed database to act as the new core data
 *  database.
 *  @param storeName            Name for the CoreData sqlite file
 *  @param seedName             [Optional] Name for the seed database sqlite in the application bundle.
 *  @param configuration        [Optional] Option configuration name to use when creating the persistent store coordinator.
 */
- (id)initWithStoreName:(NSString *)storeName seedName:(NSString *)seedName configuration:(NSString *)config;


/**
 *  Initializes a new instance. The CoreData stack is not yet available after instantiating this object
 *  and needs to be created with the `setupCoreDataStackWithCompletion:` method. If a seed database name
 *  is provided, this class will attempt to make a copy of that seed database to act as the new core data
 *  database.
 *  @param model                The ManagedObjectModel to use for the CoreData store.
 *  @param storeName            Name for the CoreData sqlite file.
 *  @param seedName             [Optional] Name for the seed database sqlite in the application bundle.
 *  @param configuration        [Optional] Option configuration name to use when creating the persistent store coordinator.
 */
- (id)initWithManagedObjectModel:(NSManagedObjectModel *)model storeName:(NSString *)storeName seedName:(NSString *)seedName configuration:(NSString *)config;


/**
 *  Performs the synchronous setup of the CoreData stack. This method will block the current thread
 *  until the operation has completed. It is recommended to call this method in a background thread that
 *  you manage.
 *
 *  @param options    A dictionary containing key-value pairs that specifies options used when calling addPersistentStoreWithType:configuration:configurationURL:options:error: on the persistent store coordinator.
 *  @param competion a block fired at the end of the setup method while still on the background thread.
 *  @return a reference to the newly created persistent store coordinator.
 */
- (NSPersistentStoreCoordinator *)setupCoreDataStackWithOptions:(NSDictionary *)options completion:(void (^)(BOOL success, NSError *error))completion;


/**
 *  Creates a new managed object context with a policy type of NSMergeByPropertyObjectTrumpMergePolicy
 *  and a concurrency type of NSPrivateQueueConcurrencyType.
 *
 *  @return a new context with the persistent store.
 */
- (NSManagedObjectContext *)createPrivateContext;


/**
 *  Creates a new context with the stack's persistent store coordinator.
 *
 *  @param mergePolicy The merge policy used to configure the new context.
 *
 *  @return a new context configured with private queue concurrency type.
 */
- (NSManagedObjectContext *)createPrivateContextWithMergePolicy:(id)mergePolicy;


/**
 *  Creates a new context with the specified options.
 *
 *  @param mergePolicy The merge policy used to configure the new context.
 *  @param type        The concurrency type used to configure the managed object context.
 *
 *  @return a new context
 */
- (NSManagedObjectContext *)createContextWithMergePolicy:(id)mergePolicy
                                         concurrencyType:(NSManagedObjectContextConcurrencyType)type;

/**
 *  Migrates the current persistent store to a new location.
 *
 *  @param options        A dictionary of options to pass to the persistent store's migration method.
 *  @param destinationURL The URL of the new store location.
 *  @param error          A pointer to any errors encountered during the migration
 *
 *  @return The migrated persistent store.
 */
- (NSPersistentStore *)migratePersistentStoreWithOptions:(NSDictionary *)options destinationStoreName:(NSString *)destinationStoreName error:(NSError **)error;


/**
 *  Removes the current persistent store from the device.
 *
 *  @return A boolean value indidcating if the removal was successful.
 */
- (BOOL)removePersistentStore;


/**
 *  Returns the default store URL. Note: this may not reflect the actual store URL for iCloud enabled stores. For that,
 *  use the URL value from the persistent store property.
 *
 *  @return A url of the default store location.
 */
- (NSURL *)defaultStoreURL;

@end
