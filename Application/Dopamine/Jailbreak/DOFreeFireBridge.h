//
//  DOFreeFireBridge.h
//  Dopamine
//
//  FreeFire attach layer. Replaces the old Processes list: a single global
//  switch connects to the FreeFire process via kernel R/W (extmod zero +
//  task_for_pid) and resolves the UnityFramework image base so the function
//  layer can act on the game exactly like the DSWUnity / darksword-fun
//  reference projects do.
//

#import <Foundation/Foundation.h>
#import <mach/mach.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const DOFreeFireBridgeAttachDidChangeNotification;

@interface DOFreeFireBridge : NSObject

+ (instancetype)sharedInstance;

// Connects to FreeFire: finds the pid, zeroes extmod counters, takes the task
// port and resolves the UnityFramework base. Returns nil on success.
- (nullable NSError *)attachWithError:(NSError **)error;

// Drops the task port and disables the function layer.
- (void)detach;

@property (nonatomic, readonly, getter=isAttached) BOOL attached;
@property (nonatomic, readonly) pid_t attachedPid;
@property (nonatomic, readonly) uint64_t unityBase;
@property (nonatomic, readonly, copy) NSString *statusText;

@end

NS_ASSUME_NONNULL_END
