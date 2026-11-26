//
//  DOJailbreaker.h
//  Dopamine
//
//  Created by Lars Fröder on 10.01.24.
//
//  Repurposed as a kernel R/W provider. The class name is kept for source
//  compatibility with the (disabled) Corellium CLI target, but its purpose is
//  now strictly: patchfinding -> kernel exploit (+ PAC/PPL where required) ->
//  stable physical R/W primitive. No jailbreak, no jailbreak state, no
//  jailbreak session and no jailbreak boot management.
//

#import <Foundation/Foundation.h>
#import <xpc/xpc.h>
#import <sys/types.h>

NS_ASSUME_NONNULL_BEGIN

// Appends a timestamped line to /var/mobile/Documents/DopamineKernelRW.log.
// Falls back to the app container if that path is not writable.
void DOKRWLog(NSString *format, ...) NS_FORMAT_FUNCTION(1,2);
NSString *DOKRWLogPath(void);
int DOKRWHelperMain(const char *socketPath);

@interface DOJailbreaker : NSObject
{
    xpc_object_t _systemInfoXdict;
    BOOL _kernelRWReady;
    uint32_t _extmodOffset;
}

+ (instancetype)sharedInstance;

@property (nonatomic, readonly) BOOL kernelRWReady;
@property (nonatomic, readonly) uint64_t kernelBase;
@property (nonatomic, readonly) uint64_t kernelSlide;
@property (nonatomic, readonly, getter=isKcallAvailable) BOOL kcallAvailable;

- (BOOL)exploitRanThisBoot;
- (BOOL)exploitStartedThisBoot;
// Reconnects to a still-running helper from a previous app launch.
- (BOOL)restoreKernelRWFromHelper;
// Resolved offset of task->extmod_statistics (0 if not resolved).
@property (nonatomic, readonly) uint32_t extmodOffset;

// Runs patchfinding, the kernel exploit (plus PAC/PPL bypass when required) and
// builds the physrw primitive. Returns nil on success. On success this process
// holds kernel R/W for the remainder of the current boot.
- (nullable NSError *)obtainKernelRW;

#pragma mark - Kernel primitives

- (uint64_t)kread64:(uint64_t)addr;
- (uint32_t)kread32:(uint64_t)addr;
- (int)kreadbuf:(uint64_t)addr to:(void *)out size:(size_t)size;

- (int)kwrite64:(uint64_t)addr value:(uint64_t)value;
- (int)kwrite32:(uint64_t)addr value:(uint32_t)value;
- (int)kwritebuf:(uint64_t)addr from:(const void *)in size:(size_t)size;

// Returns the raw result register (x0). Returns 0 if kcall is unavailable.
- (uint64_t)kcall:(uint64_t)func argc:(int)argc argv:(const uint64_t *)argv;

- (int)kalloc:(uint64_t *)addr size:(uint64_t)size;
- (int)kfree:(uint64_t)addr size:(uint64_t)size;
- (int)kmap:(uint64_t)pa size:(uint64_t)size out:(void **)uaddr;

- (int)physreadbuf:(uint64_t)pa to:(void *)out size:(size_t)size;
- (int)physwritebuf:(uint64_t)pa from:(const void *)in size:(size_t)size;

#pragma mark - Task / extmod helpers

// Kernel task_t pointer for a pid (0 if not found).
- (uint64_t)kernelTaskForPid:(pid_t)pid;

// Zeroes the vm_extmod_statistics block (6 x int64, 48 bytes) located at task + offset.
// The offset of task->extmod_statistics is kernel-build specific and is not
// currently exported by XPF, so it must be supplied by the caller.
- (BOOL)zeroExtmodStatisticsForTask:(uint64_t)task offset:(uint32_t)offset;
- (BOOL)zeroExtmodStatisticsForPid:(pid_t)pid offset:(uint32_t)offset;

// Resolves (and caches) the extmod offset for the running kernel build.
// Resolution order: learned cache -> runtime discovery. Returns NO if the
// offset could not be determined; no kernel write happens in that case.
- (BOOL)resolveExtmodOffset;
- (BOOL)zeroExtmodStatisticsForTask:(uint64_t)task;
- (BOOL)zeroExtmodStatisticsForPid:(pid_t)pid;

@end

NS_ASSUME_NONNULL_END
