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

@interface DOJailbreaker : NSObject
{
    xpc_object_t _systemInfoXdict;
    BOOL _kernelRWReady;
}

+ (instancetype)sharedInstance;

@property (nonatomic, readonly) BOOL kernelRWReady;
@property (nonatomic, readonly) uint64_t kernelBase;
@property (nonatomic, readonly) uint64_t kernelSlide;
@property (nonatomic, readonly, getter=isKcallAvailable) BOOL kcallAvailable;

// Runs patchfinding, the kernel exploit (plus PAC/PPL bypass when required) and
// builds the physrw primitive. Returns nil on success. On success this process
// holds kernel R/W for the remainder of the current boot.
- (nullable NSError *)obtainKernelRW;

// Contiguous mapping workaround (required on some devices before exploitation).
- (BOOL)contiguousMappingWorkaroundNeeded;
- (void)applyContiguousMappingWorkaround;

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

// Zeroes the vm_extmod_statistics block (6 x int64, 48 bytes) at task + offset.
// The offset of task->extmod_statistics is kernel-build specific and is not
// currently exported by XPF, so it must be supplied by the caller.
- (BOOL)zeroExtmodStatisticsForTask:(uint64_t)task offset:(uint32_t)offset;
- (BOOL)zeroExtmodStatisticsForPid:(pid_t)pid offset:(uint32_t)offset;

@end

NS_ASSUME_NONNULL_END
