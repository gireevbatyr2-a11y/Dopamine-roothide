//
//  DOJailbreaker.m
//  Dopamine
//
//  Created by Lars Fröder on 10.01.24.
//
//  Kernel R/W provider: patchfinding -> kernel exploit (+ PAC/PPL) -> physrw.
//  This file deliberately contains no jailbreak payload, state, session or boot
//  management. It stops once a stable kernel R/W primitive is available.
//

#import "DOJailbreaker.h"
#import "DOEnvironmentManager.h"
#import "DOExploitManager.h"
#import "DOUIManager.h"
#import <sys/stat.h>
#import <xpf/xpf.h>
#import <dlfcn.h>
#import <unistd.h>
#import <string.h>
#import <stdarg.h>
#import <time.h>
#import <stdio.h>
#import <stdlib.h>
#import <spawn.h>
#import <signal.h>
#import <sys/wait.h>
#import <sys/sysctl.h>
#import <mach/mach.h>
#import <mach/vm_region.h>
#import <mach/ndr.h>
#import <libjailbreak/primitives.h>
#import <libjailbreak/primitives_IOSurface.h>
#import <libjailbreak/physrw_pte.h>
#import <libjailbreak/physrw.h>
#import <libjailbreak/translation.h>
#import <libjailbreak/kernel.h>
#import <libjailbreak/info.h>
#import <libjailbreak/util.h>
#import <libjailbreak/kcall_arm64.h>
#import <sys/utsname.h>
#import "clock_alarm.h"
#import <IOSurface/IOSurfaceRef.h>

extern char **environ;
extern kern_return_t task_for_pid(mach_port_t target_tport, int pid, mach_port_t *t);
extern kern_return_t task_info(task_name_t target_task, task_flavor_t flavor, task_info_t task_info_out, mach_msg_type_number_t *task_info_outCnt);

#define DO_TASK_EXTMOD_INFO 19
#define DO_EXTMOD_OFFSET_CACHE @"/var/mobile/Documents/kernelrw_extmod_offsets.plist"

NSString *const JBErrorDomain = @"JBErrorDomain";
typedef NS_ENUM(NSInteger, JBErrorCode) {
    JBErrorCodeFailedToFindKernel            = -1,
    JBErrorCodeFailedKernelPatchfinding      = -2,
    JBErrorCodeFailedLoadingExploit          = -3,
    JBErrorCodeFailedExploitation            = -4,
    JBErrorCodeFailedBuildingPhysRW          = -5,
    JBErrorCodeFailedCleanup                 = -6,
};

#pragma mark - File logging

static NSString *gDOKRWLogPath;

NSString *DOKRWLogPath(void)
{
    return gDOKRWLogPath ?: @"(not written)";
}

static NSString *DOKRWLogFallbackPath(void)
{
    static NSString *fallback;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *dir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        fallback = [dir stringByAppendingPathComponent:@"DopamineKernelRW.log"];
    });
    return fallback;
}

static void DOKRWWriteState(NSString *uuid, BOOL ran)
{
    NSString *content = [NSString stringWithFormat:@"boot=%@\nran=%d\n", uuid ?: @"?", ran];
    NSArray<NSString *> *paths = @[
        @"/var/mobile/Documents/DopamineKernelRW.state",
        @"/var/mobile/Library/Logs/DopamineKernelRW.state",
        [DOKRWLogFallbackPath().stringByDeletingLastPathComponent stringByAppendingPathComponent:@"DopamineKernelRW.state"],
    ];
    for (NSString *path in paths) {
        [[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
        if ([content writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil]) break;
    }
}

void DOKRWLog(NSString *format, ...)
{
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    time_t now = time(NULL);
    struct tm tmnow;
    localtime_r(&now, &tmnow);
    char timestamp[32] = {0};
    strftime(timestamp, sizeof(timestamp), "%Y-%m-%d %H:%M:%S", &tmnow);

    NSString *line = [NSString stringWithFormat:@"[%s] %@\n", timestamp, message];
    NSLog(@"[KernelRW] %@", message);

    NSArray<NSString *> *candidates = @[
        @"/var/mobile/Documents/DopamineKernelRW.log",
        @"/var/mobile/Library/Logs/DopamineKernelRW.log",
        DOKRWLogFallbackPath(),
    ];

    FILE *file = NULL;
    NSString *usedPath = nil;
    for (NSString *path in candidates) {
        [[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
        file = fopen(path.fileSystemRepresentation, "a");
        if (file) {
            usedPath = path;
            break;
        }
    }
    if (file) {
        fputs(line.UTF8String, file);
        fclose(file);
        if (!gDOKRWLogPath) {
            gDOKRWLogPath = [usedPath copy];
            NSLog(@"[KernelRW] log file: %@", gDOKRWLogPath);
        }
    }
}

static NSString *DOKRWCurrentBootSessionUUID(void)
{
    char uuid[64] = {0};
    size_t size = sizeof(uuid);
    if (sysctlbyname("kern.bootsessionuuid", uuid, &size, NULL, 0) != 0) {
        return nil;
    }
    return [NSString stringWithUTF8String:uuid];
}

@interface DOJailbreaker ()
- (NSError *)gatherSystemInformation;
- (NSError *)doExploitation;
- (NSError *)buildPhysRWPrimitive;
- (NSError *)cleanUpExploits;
@end

@implementation DOJailbreaker

+ (instancetype)sharedInstance
{
    static DOJailbreaker *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[DOJailbreaker alloc] init];
    });
    return shared;
}

#pragma mark - Public state

- (BOOL)kernelRWReady
{
    return _kernelRWReady;
}

- (uint64_t)kernelBase
{
    return gSystemInfo.kernelConstant.base;
}

- (uint64_t)kernelSlide
{
    return gSystemInfo.kernelConstant.slide;
}

- (BOOL)isKcallAvailable
{
    return gPrimitives.kcall != NULL;
}

#pragma mark - Pipeline

- (NSError *)obtainKernelRW
{
    @synchronized (self) {
        if (_kernelRWReady) return nil;

        NSString *currentBoot = DOKRWCurrentBootSessionUUID();
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *lastBoot = [defaults stringForKey:@"DOKRWBootSessionUUID"];
        BOOL ranThisBoot = [defaults boolForKey:@"DOKRWExploitRan"];
        DOKRWLog(@"boot: uuid=%@ last=%@ ran=%d prefs=%@",
                 currentBoot ?: @"?", lastBoot ?: @"?", ranThisBoot,
                 [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"Preferences"]);
        DOKRWWriteState(currentBoot, ranThisBoot);
        if (currentBoot && lastBoot && [currentBoot isEqualToString:lastBoot] && ranThisBoot) {
            DOKRWLog(@"obtainKernelRW: exploit already ran in this boot; reboot required");
            return [NSError errorWithDomain:JBErrorDomain code:JBErrorCodeFailedExploitation userInfo:@{NSLocalizedDescriptionKey:@"Kernel R/W was already acquired in this boot. Reboot the device before running the exploit again."}];
        }
        if (currentBoot && (!lastBoot || ![currentBoot isEqualToString:lastBoot])) {
            [defaults setBool:NO forKey:@"DOKRWExploitRan"];
            [defaults setObject:currentBoot forKey:@"DOKRWBootSessionUUID"];
            [defaults synchronize];
        }

        DOKRWLog(@"obtainKernelRW: start");
        NSError *error = [self gatherSystemInformation];
        if (error) {
            DOKRWLog(@"obtainKernelRW: patchfinding failed: %@", error.localizedDescription);
            return error;
        }
        DOKRWLog(@"obtainKernelRW: patchfinding done");

        error = [self doExploitation];
        if (error) {
            DOKRWLog(@"obtainKernelRW: exploitation failed: %@", error.localizedDescription);
            [self cleanUpExploits];
            return error;
        }
        DOKRWLog(@"obtainKernelRW: exploitation done (kcall=%@)", [self isKcallAvailable] ? @"yes" : @"no");

        error = [self buildPhysRWPrimitive];
        if (error) {
            DOKRWLog(@"obtainKernelRW: physrw failed: %@", error.localizedDescription);
            [self cleanUpExploits];
            return error;
        }
        DOKRWLog(@"obtainKernelRW: physrw done");

        NSError *cleanupError = [self cleanUpExploits];
        if (cleanupError) {
            DOKRWLog(@"obtainKernelRW: cleanup warning: %@", cleanupError.localizedDescription);
        }

        _kernelRWReady = YES;
        if (currentBoot) {
            [defaults setBool:YES forKey:@"DOKRWExploitRan"];
            [defaults setObject:currentBoot forKey:@"DOKRWBootSessionUUID"];
            [defaults synchronize];
            DOKRWWriteState(currentBoot, YES);
        }
        DOKRWLog(@"obtainKernelRW: ready base=0x%llx slide=0x%llx kcall=%@",
                 (unsigned long long)gSystemInfo.kernelConstant.base,
                 (unsigned long long)gSystemInfo.kernelConstant.slide,
                 [self isKcallAvailable] ? @"yes" : @"no");
        return nil;
    }
}

- (NSError *)gatherSystemInformation
{
    NSString *kernelPath = [[DOEnvironmentManager sharedManager] accessibleKernelPath];
    if (!kernelPath) return [NSError errorWithDomain:JBErrorDomain code:JBErrorCodeFailedToFindKernel userInfo:@{NSLocalizedDescriptionKey:@"Failed to find kernelcache. Ensure your device is properly connected to the internet. If it still does not work, try installing via TrollStore instead."}];
    NSLog(@"Kernel at %@", kernelPath);

    NSString *sptmPath = [[DOEnvironmentManager sharedManager] accessibleSPTMPath];
    if (sptmPath) {
        NSLog(@"SPTM at %@", sptmPath);
    }
    NSString *txmPath = [[DOEnvironmentManager sharedManager] accessibleTXMPath];
    if (txmPath) {
        NSLog(@"TXM at %@", txmPath);
    }

    [[DOUIManager sharedInstance] sendLog:DOLocalizedString(@"Patchfinding") debug:NO];

    int r = xpf_start_with_kernel_path(kernelPath.fileSystemRepresentation, sptmPath ? sptmPath.fileSystemRepresentation : NULL, txmPath ? txmPath.fileSystemRepresentation : NULL);
    if (r == 0) {
        char *sets[] = {
            "translation",
            "trustcache",
            "sandbox",
            "physmap",
            "struct",
            "physrw",
            "IOSurface",
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
        };

        uint32_t idx = 0;
        while(sets[++idx]);

        if (xpf_set_is_supported("devmode")) {
            sets[idx++] = "devmode";
        }
        if (xpf_set_is_supported("badRecovery")) {
            sets[idx++] = "badRecovery";
        }
        if (xpf_set_is_supported("arm64kcall")) {
            sets[idx++] = "arm64kcall";
        }
        if (xpf_set_is_supported("perfkrw")) {
            sets[idx++] = "perfkrw";
        }

        _systemInfoXdict = roothide_xpf_construct_offset_dictionary_wrapper((const char **)sets);
        if (_systemInfoXdict) {
            xpc_dictionary_set_uint64(_systemInfoXdict, "kernelConstant.staticBase", gXPF.kernelBase);
            if (gXPF.sptm) {
                xpc_dictionary_set_uint64(_systemInfoXdict, "kernelConstant.staticSptmBase", gXPF.sptmBase);
            }
            if (gXPF.txm) {
                xpc_dictionary_set_uint64(_systemInfoXdict, "kernelConstant.staticTxmBase", gXPF.txmBase);
            }
            printf("System Info:\n");
            xpc_dictionary_apply(_systemInfoXdict, ^bool(const char *key, xpc_object_t value) {
                if (xpc_get_type(value) == XPC_TYPE_UINT64) {
                    printf("0x%016llx <- %s\n", xpc_uint64_get_value(value), key);
                }
                return true;
            });
        }
        if (!_systemInfoXdict) {
            return [NSError errorWithDomain:JBErrorDomain code:JBErrorCodeFailedKernelPatchfinding userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"XPF failed with error: (%s)", xpf_get_error()]}];
        }
        xpf_stop();
    }
    else {
        NSError *error = [NSError errorWithDomain:JBErrorDomain code:JBErrorCodeFailedKernelPatchfinding userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"XPF start failed with error: (%s)", xpf_get_error()]}];
        xpf_stop();
        return error;
    }

    jbinfo_initialize_dynamic_offsets(_systemInfoXdict);
    jbinfo_initialize_hardcoded_offsets();

    if ([NSBundle mainBundle].bundleIdentifier) {
        gSystemInfo.jailbreakInfo.appIdentifier = strdup([NSBundle mainBundle].bundleIdentifier.UTF8String);
    }

    _systemInfoXdict = jbinfo_get_serialized();

    if (_systemInfoXdict) {
        printf("System Info libjailbreak:\n");
        xpc_dictionary_apply(_systemInfoXdict, ^bool(const char *key, xpc_object_t value) {
            if (xpc_get_type(value) == XPC_TYPE_UINT64) {
                if (xpc_uint64_get_value(value)) {
                    printf("0x%016llx <- %s\n", xpc_uint64_get_value(value), key);
                }
            }
            return true;
        });
    }

    return nil;
}

- (NSError *)doExploitation
{
    DOExploit *kernelExploit = [DOExploitManager sharedManager].selectedKernelExploit;
    DOExploit *pacBypass     = [DOExploitManager sharedManager].selectedPACBypass;
    DOExploit *pplBypass     = [DOExploitManager sharedManager].selectedPPLBypass;

    if (!kernelExploit) {
        return [NSError errorWithDomain:JBErrorDomain code:JBErrorCodeFailedExploitation userInfo:@{NSLocalizedDescriptionKey:@"Kernel exploit is required but we did not find any"}];
    }
    if (!pacBypass && [DOEnvironmentManager sharedManager].isPACBypassRequired) {
        return [NSError errorWithDomain:JBErrorDomain code:JBErrorCodeFailedExploitation userInfo:@{NSLocalizedDescriptionKey:@"PAC bypass is required but we did not find any"}];
    }
    if (!pplBypass && [DOEnvironmentManager sharedManager].isPPLBypassRequired) {
        if ([DOEnvironmentManager sharedManager].isSPTM) {
            return [NSError errorWithDomain:JBErrorDomain code:JBErrorCodeFailedExploitation userInfo:@{NSLocalizedDescriptionKey:@"SPTM bypass is required but we did not find any"}];
        }
        else {
            return [NSError errorWithDomain:JBErrorDomain code:JBErrorCodeFailedExploitation userInfo:@{NSLocalizedDescriptionKey:@"PPL bypass is required but we did not find any"}];
        }
    }

    DOKRWLog(@"exploit: kernel=%@ pac=%@ ppl=%@", kernelExploit.name, pacBypass.name ?: @"none", pplBypass.name ?: @"none");

    [[DOUIManager sharedInstance] sendLog:[NSString stringWithFormat:DOLocalizedString(@"Exploiting Kernel (%@)"), kernelExploit.name] debug:NO];
    if ([kernelExploit load] != 0) return [NSError errorWithDomain:JBErrorDomain code:JBErrorCodeFailedLoadingExploit userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Failed to load kernel exploit: %s", dlerror()]}];
    if ([kernelExploit run] != 0) return [NSError errorWithDomain:JBErrorDomain code:JBErrorCodeFailedExploitation userInfo:@{NSLocalizedDescriptionKey:@"Failed to exploit kernel"}];

    jbinfo_initialize_boot_constants();
    libjailbreak_translation_init();
    libjailbreak_IOSurface_primitives_init();

    if (pacBypass) {
        [[DOUIManager sharedInstance] sendLog:[NSString stringWithFormat:DOLocalizedString(@"Bypassing PAC (%@)"), pacBypass.name] debug:NO];
        if ([pacBypass load] != 0) {[kernelExploit cleanup]; return [NSError errorWithDomain:JBErrorDomain code:JBErrorCodeFailedLoadingExploit userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Failed to load PAC bypass: %s", dlerror()]}];};
        if ([pacBypass run] != 0) {[kernelExploit cleanup]; return [NSError errorWithDomain:JBErrorDomain code:JBErrorCodeFailedExploitation userInfo:@{NSLocalizedDescriptionKey:@"Failed to bypass PAC"}];}
        gSystemInfo.jailbreakInfo.usesPACBypass = true;
    }

    if ([[DOEnvironmentManager sharedManager] isPPLBypassRequired]) {
        if ([DOEnvironmentManager sharedManager].isSPTM) {
            [[DOUIManager sharedInstance] sendLog:[NSString stringWithFormat:DOLocalizedString(@"Bypassing SPTM (%@)"), pplBypass.name] debug:NO];
        }
        else {
            [[DOUIManager sharedInstance] sendLog:[NSString stringWithFormat:DOLocalizedString(@"Bypassing PPL (%@)"), pplBypass.name] debug:NO];
        }

        if ([pplBypass load] != 0) {[pacBypass cleanup]; [kernelExploit cleanup]; return [NSError errorWithDomain:JBErrorDomain code:JBErrorCodeFailedLoadingExploit userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Failed to load PPL bypass: %s", dlerror()]}];};
        if ([pplBypass run] != 0) {[pacBypass cleanup]; [kernelExploit cleanup]; return [NSError errorWithDomain:JBErrorDomain code:JBErrorCodeFailedExploitation userInfo:@{NSLocalizedDescriptionKey:@"Failed to bypass PPL"}];}
    }

    if (![DOEnvironmentManager sharedManager].isArm64e) {
        arm64_kcall_init();
    }

    return nil;
}

- (NSError *)buildPhysRWPrimitive
{
    int r = -1;
    BOOL usePTE = device_supports_physrw_pte();
    DOKRWLog(@"physrw: using %@", usePTE ? @"pte" : @"physmap");
    if (usePTE) {
        r = libjailbreak_physrw_pte_init(false, 0);
    }
    else {
        r = libjailbreak_physrw_init(false);
    }
    if (r != 0) {
        return [NSError errorWithDomain:JBErrorDomain code:JBErrorCodeFailedBuildingPhysRW userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Failed to build phys r/w primitive: %d", r]}];
    }
    return nil;
}

- (NSError *)cleanUpExploits
{
    int r = [[DOExploitManager sharedManager] cleanUpExploits];
    DOKRWLog(@"cleanup: exploits result=%d", r);
    if (r != 0) return [NSError errorWithDomain:JBErrorDomain code:JBErrorCodeFailedCleanup userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Failed to cleanup exploits: %d", r]}];
    IOSurface_map_cleanup();
    return nil;
}

#pragma mark - Kernel primitives

- (uint64_t)kread64:(uint64_t)addr
{
    return kread64(addr);
}

- (uint32_t)kread32:(uint64_t)addr
{
    return kread32(addr);
}

- (int)kreadbuf:(uint64_t)addr to:(void *)out size:(size_t)size
{
    return kreadbuf(addr, out, size);
}

- (int)kwrite64:(uint64_t)addr value:(uint64_t)value
{
    return kwrite64(addr, value);
}

- (int)kwrite32:(uint64_t)addr value:(uint32_t)value
{
    return kwrite32(addr, value);
}

- (int)kwritebuf:(uint64_t)addr from:(const void *)in size:(size_t)size
{
    return kwritebuf(addr, in, size);
}

- (uint64_t)kcall:(uint64_t)func argc:(int)argc argv:(const uint64_t *)argv
{
    uint64_t result = 0;
    if (kcall(&result, func, argc, argv) != 0) return 0;
    return result;
}

- (int)kalloc:(uint64_t *)addr size:(uint64_t)size
{
    return kalloc(addr, size);
}

- (int)kfree:(uint64_t)addr size:(uint64_t)size
{
    return kfree(addr, size);
}

- (int)kmap:(uint64_t)pa size:(uint64_t)size out:(void **)uaddr
{
    return kmap(pa, size, uaddr);
}

- (int)physreadbuf:(uint64_t)pa to:(void *)out size:(size_t)size
{
    return physreadbuf(pa, out, size);
}

- (int)physwritebuf:(uint64_t)pa from:(const void *)in size:(size_t)size
{
    return physwritebuf(pa, in, size);
}

#pragma mark - Task / extmod helpers

- (uint64_t)kernelTaskForPid:(pid_t)pid
{
    uint64_t proc = proc_find(pid);
    if (!proc) return 0;
    uint64_t task = proc_task(proc);
    proc_rele(proc);
    return task;
}

- (BOOL)zeroExtmodStatisticsForTask:(uint64_t)task offset:(uint32_t)offset
{
    if (!task || offset == 0) return NO;
    uint64_t zeros[6] = {0};
    return kwritebuf(task + offset, zeros, sizeof(zeros)) == 0;
}

- (BOOL)zeroExtmodStatisticsForPid:(pid_t)pid offset:(uint32_t)offset
{
    return [self zeroExtmodStatisticsForTask:[self kernelTaskForPid:pid] offset:offset];
}

#pragma mark - extmod offset resolution

typedef struct {
    const char *osversion;
    uint32_t offset;
} DOKRWExtmodOffsetEntry;

// Pinned offsets for known kernel builds. Runtime discovery results are cached
// per build in /var/mobile/Documents/kernelrw_extmod_offsets.plist, so this
// table only needs entries for builds you want to force without discovery.
static const DOKRWExtmodOffsetEntry kDOKRWExtmodOffsets[] = {
    // { "22F76", 0x000 },
    { NULL, 0 },
};

static NSString *DOKRWOSVersion(void)
{
    char version[64] = {0};
    size_t size = sizeof(version);
    if (sysctlbyname("kern.osversion", version, &size, NULL, 0) != 0) {
        return nil;
    }
    return [NSString stringWithUTF8String:version];
}

- (uint32_t)extmodOffset
{
    return _extmodOffset;
}

- (BOOL)readOwnExtmodStatistics:(int64_t *)stats
{
    uint64_t buffer[8] = {0}; // struct task_extmod_info: uuid[16] + 6 x int64
    mach_msg_type_number_t count = 16;
    kern_return_t kr = task_info(mach_task_self(), DO_TASK_EXTMOD_INFO, (task_info_t)buffer, &count);
    if (kr != KERN_SUCCESS || count < 16) return NO;
    memcpy(stats, ((uint8_t *)buffer) + 16, 48);
    return YES;
}

static BOOL DOKRWStatsAreZero(const int64_t *stats)
{
    for (int i = 0; i < 6; i++) {
        if (stats[i] != 0) return NO;
    }
    return YES;
}

// Looks up another task's port. The kernel only bumps extmod counters when the
// target task differs from the caller, so this is what makes our own
// extmod_statistics block non-zero and uniquely findable in the task struct.
- (BOOL)perturbOwnExtmodStatistics
{
    BOOL perturbed = NO;

    uint64_t selfProc = proc_find(getpid());
    if (selfProc) {
        uint64_t cur = kread64(selfProc + koffsetof(proc, list_next));
        int guard = 0;
        while (cur && cur != selfProc && guard++ < 128) {
            pid_t pid = kread32(cur + koffsetof(proc, pid));
            if (pid > 0 && pid != getpid()) {
                mach_port_t port = MACH_PORT_NULL;
                if (task_for_pid(mach_task_self(), pid, &port) == KERN_SUCCESS) {
                    mach_port_deallocate(mach_task_self(), port);
                    perturbed = YES;
                    DOKRWLog(@"extmod: perturbed via task_for_pid(%d)", pid);
                    break;
                }
            }
            uint64_t next = kread64(cur + koffsetof(proc, list_next));
            if (!next) break;
            cur = next;
        }
        proc_rele(selfProc);
    }

    if (!perturbed) {
        NSString *exe = [NSBundle mainBundle].executablePath;
        if (exe) {
            posix_spawnattr_t attr;
            posix_spawnattr_init(&attr);
            posix_spawnattr_setflags(&attr, POSIX_SPAWN_SETPGROUP);
            pid_t child = 0;
            char *argv[] = { (char *)exe.fileSystemRepresentation, "krw-perturb-helper", NULL };
            int rc = posix_spawn(&child, exe.fileSystemRepresentation, NULL, &attr, argv, environ);
            posix_spawnattr_destroy(&attr);
            if (rc == 0 && child > 0) {
                usleep(300000);
                mach_port_t port = MACH_PORT_NULL;
                if (task_for_pid(mach_task_self(), child, &port) == KERN_SUCCESS) {
                    mach_port_deallocate(mach_task_self(), port);
                    perturbed = YES;
                    DOKRWLog(@"extmod: perturbed via helper pid %d", child);
                }
                kill(child, SIGKILL);
                waitpid(child, NULL, 0);
            } else {
                DOKRWLog(@"extmod: helper spawn failed (%d)", rc);
            }
        }
    }

    return perturbed;
}

- (BOOL)verifyExtmodOffset:(uint32_t)offset task:(uint64_t)task
{
    if (!offset || !task) return NO;
    int64_t stats[6] = {0};
    if (![self readOwnExtmodStatistics:stats]) return NO;
    int64_t disk[6] = {0};
    if (kreadbuf(task + offset, disk, sizeof(disk)) != 0) return NO;
    return memcmp(stats, disk, sizeof(stats)) == 0;
}

- (BOOL)discoverExtmodOffset:(uint32_t *)outOffset task:(uint64_t)task
{
    uint8_t *buffer = malloc(0x1000);
    if (!buffer) return NO;

    NSMutableSet<NSNumber *> *candidates = nil;

    for (int attempt = 0; attempt < 4; attempt++) {
        if (attempt > 0 && ![self perturbOwnExtmodStatistics]) break;

        int64_t stats[6] = {0};
        if (![self readOwnExtmodStatistics:stats]) break;
        if (DOKRWStatsAreZero(stats)) continue;

        size_t got = 0;
        for (size_t off = 0; off < 0x1000; off += 0x100) {
            if (kreadbuf(task + off, buffer + off, 0x100) != 0) break;
            got = off + 0x100;
        }

        NSMutableSet<NSNumber *> *matches = [NSMutableSet new];
        for (size_t off = 0; off + 48 <= got; off += 8) {
            if (memcmp(buffer + off, stats, 48) == 0) {
                [matches addObject:@(off)];
            }
        }

        DOKRWLog(@"extmod: attempt %d stats=[%lld,%lld,%lld,%lld,%lld,%lld] matches=%lu",
                 attempt, stats[0], stats[1], stats[2], stats[3], stats[4], stats[5],
                 (unsigned long)matches.count);

        if (matches.count == 0) {
            candidates = nil;
            break;
        }
        if (!candidates) {
            candidates = [matches mutableCopy];
        } else {
            [candidates intersectSet:matches];
        }
        if (candidates.count == 1) break;
    }

    free(buffer);

    if (candidates.count == 1) {
        uint32_t offset = (uint32_t)[candidates.anyObject unsignedIntegerValue];
        if (offset != 0 && offset < 0x1000) {
            *outOffset = offset;
            return YES;
        }
    }
    if (candidates.count > 1) {
        DOKRWLog(@"extmod: ambiguous candidates: %@", candidates);
    }
    return NO;
}

- (BOOL)resolveExtmodOffset
{
    @synchronized (self) {
        if (_extmodOffset) return YES;
        if (!_kernelRWReady) {
            DOKRWLog(@"extmod: kernel R/W not ready");
            return NO;
        }

        NSString *osversion = DOKRWOSVersion();
        uint64_t proc = proc_find(getpid());
        if (!proc) return NO;
        uint64_t task = proc_task(proc);
        proc_rele(proc);
        if (!task) return NO;

        NSDictionary *cachedDict = [NSDictionary dictionaryWithContentsOfFile:DO_EXTMOD_OFFSET_CACHE];
        if (osversion && cachedDict[osversion]) {
            uint32_t offset = [cachedDict[osversion] unsignedIntValue];
            if ([self verifyExtmodOffset:offset task:task]) {
                _extmodOffset = offset;
                DOKRWLog(@"extmod: using cached offset 0x%x for %@", offset, osversion);
                return YES;
            }
            DOKRWLog(@"extmod: cached offset 0x%x for %@ failed verification", offset, osversion);
        }

        for (int i = 0; kDOKRWExtmodOffsets[i].osversion; i++) {
            NSString *pinnedVersion = [NSString stringWithUTF8String:kDOKRWExtmodOffsets[i].osversion];
            if (osversion && [osversion isEqualToString:pinnedVersion]) {
                uint32_t offset = kDOKRWExtmodOffsets[i].offset;
                if ([self verifyExtmodOffset:offset task:task]) {
                    _extmodOffset = offset;
                    DOKRWLog(@"extmod: using pinned offset 0x%x for %@", offset, osversion);
                    return YES;
                }
                DOKRWLog(@"extmod: pinned offset 0x%x for %@ failed verification", offset, osversion);
            }
        }

        uint32_t discovered = 0;
        if ([self discoverExtmodOffset:&discovered task:task]) {
            _extmodOffset = discovered;
            if (osversion) {
                NSMutableDictionary *cache = cachedDict ? [cachedDict mutableCopy] : [NSMutableDictionary new];
                cache[osversion] = @(discovered);
                [cache writeToFile:DO_EXTMOD_OFFSET_CACHE atomically:YES];
            }
            DOKRWLog(@"extmod: resolved offset 0x%x for %@", discovered, osversion ?: @"?");
            return YES;
        }

        DOKRWLog(@"extmod: failed to resolve offset for %@", osversion ?: @"?");
        return NO;
    }
}

- (BOOL)zeroExtmodStatisticsForTask:(uint64_t)task
{
    if (!task) return NO;
    if (!_extmodOffset && ![self resolveExtmodOffset]) return NO;
    return [self zeroExtmodStatisticsForTask:task offset:_extmodOffset];
}

- (BOOL)zeroExtmodStatisticsForPid:(pid_t)pid
{
    return [self zeroExtmodStatisticsForTask:[self kernelTaskForPid:pid]];
}

@end
