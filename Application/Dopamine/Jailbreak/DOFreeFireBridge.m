//
//  DOFreeFireBridge.m
//  Dopamine
//

#import "DOFreeFireBridge.h"
#import "DOJailbreaker.h"
#import <libjailbreak/libjailbreak.h>

NSString * const DOFreeFireBridgeAttachDidChangeNotification = @"DOFreeFireBridgeAttachDidChange";

extern int proc_listpids(uint32_t type, uint32_t typeinfo, void *buffer, int buffersize);
extern int proc_name(int pid, void *buffer, uint32_t buffersize);
extern kern_return_t task_for_pid(mach_port_t target_tport, int pid, mach_port_t *t);
extern kern_return_t mach_vm_read_overwrite(vm_map_t target_task, mach_vm_address_t address,
                                            mach_vm_size_t size, mach_vm_address_t data,
                                            mach_vm_size_t *outsize);
extern kern_return_t mach_vm_region_recurse(vm_map_t target_task, mach_vm_address_t *address,
                                            mach_vm_size_t *size, natural_t *depth,
                                            vm_region_recurse_info_t info,
                                            mach_msg_type_number_t *infoCnt);

#ifndef PROC_ALL_PIDS
#define PROC_ALL_PIDS 1
#endif

// iOS user-space image region; excludes the dyld shared cache above it.
static const uint64_t kImageRegionLow  = 0x100000000ULL;
static const uint64_t kImageRegionHigh = 0x1600000000ULL;

@interface DOFreeFireBridge ()
@property (nonatomic, assign, getter=isAttached) BOOL attached;
@property (nonatomic, assign) pid_t attachedPid;
@property (nonatomic, assign) uint64_t unityBase;
@property (nonatomic, assign) mach_port_t taskPort;
@end

@implementation DOFreeFireBridge

+ (instancetype)sharedInstance
{
    static DOFreeFireBridge *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DOFreeFireBridge alloc] init];
    });
    return instance;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _attached = NO;
        _attachedPid = 0;
        _unityBase = 0;
        _taskPort = MACH_PORT_NULL;
    }
    return self;
}

- (NSString *)statusText
{
    if (!self.attached) return @"not attached";
    return [NSString stringWithFormat:@"pid %d · UnityFramework 0x%llx",
            self.attachedPid, (unsigned long long)self.unityBase];
}

// ------------------------------------------------------------------- pid

- (pid_t)findFreeFirePid
{
    int size = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
    if (size <= 0) return -1;
    NSMutableData *data = [NSMutableData dataWithLength:(NSUInteger)size];
    int used = proc_listpids(PROC_ALL_PIDS, 0, data.mutableBytes, size);
    if (used <= 0) return -1;
    int count = used / (int)sizeof(pid_t);
    pid_t *pids = (pid_t *)data.mutableBytes;
    for (int i = 0; i < count; i++) {
        pid_t pid = pids[i];
        if (pid <= 0) continue;
        char name[256] = {0};
        if (proc_name(pid, name, sizeof(name)) <= 0) continue;
        NSString *procName = [NSString stringWithUTF8String:name];
        if (procName && [procName.lowercaseString containsString:@"freefire"]) {
            return pid;
        }
    }
    return -1;
}

// ------------------------------------------------- Mach-O install-name check
// Ported from DSWUnity / darksword-fun (ff_is_module_macho): a mapped base is
// a real dylib when its LC_ID_DYLIB install name contains image_name. The
// result is self-validating, no dyld_all_image_infos dependency.

- (BOOL)regionIsImageNamed:(uint64_t)base imageName:(const char *)imageName
{
    if (base < kImageRegionLow || base >= kImageRegionHigh) return NO;

    struct mach_header_64 header;
    memset(&header, 0, sizeof(header));
    mach_vm_size_t got = 0;
    kern_return_t kr = mach_vm_read_overwrite(self.taskPort, (mach_vm_address_t)base,
                                              sizeof(header), (mach_vm_address_t)&header, &got);
    if (kr != KERN_SUCCESS || got != sizeof(header)) return NO;
    if (header.magic != MH_MAGIC_64 || header.filetype != MH_DYLIB ||
        header.ncmds == 0 || header.ncmds >= 256) return NO;

    uint64_t cmdOffset = base + sizeof(struct mach_header_64);
    uint64_t commandsEnd = cmdOffset + header.sizeofcmds;

    for (uint32_t i = 0; i < header.ncmds; i++) {
        uint32_t cmd = 0, cmdsize = 0;
        kr = mach_vm_read_overwrite(self.taskPort, (mach_vm_address_t)cmdOffset, sizeof(cmd),
                                    (mach_vm_address_t)&cmd, &got);
        if (kr != KERN_SUCCESS || got != sizeof(cmd)) break;
        kr = mach_vm_read_overwrite(self.taskPort, (mach_vm_address_t)cmdOffset + 4, sizeof(cmdsize),
                                    (mach_vm_address_t)&cmdsize, &got);
        if (kr != KERN_SUCCESS || got != sizeof(cmdsize)) break;
        if (cmdsize < 8 || cmdsize > 4096 || cmdOffset + cmdsize > commandsEnd) break;

        if (cmd == LC_ID_DYLIB) {
            uint32_t strOffset = 0;
            kr = mach_vm_read_overwrite(self.taskPort, (mach_vm_address_t)cmdOffset + 8, sizeof(strOffset),
                                        (mach_vm_address_t)&strOffset, &got);
            if (kr != KERN_SUCCESS || got != sizeof(strOffset) || strOffset >= cmdsize) break;
            char nameBuf[128] = {0};
            size_t readLen = sizeof(nameBuf) - 1;
            if (cmdsize - strOffset < readLen) readLen = cmdsize - strOffset;
            kr = mach_vm_read_overwrite(self.taskPort, (mach_vm_address_t)cmdOffset + strOffset, readLen,
                                        (mach_vm_address_t)nameBuf, &got);
            if (kr != KERN_SUCCESS || got != readLen) break;
            return strstr(nameBuf, imageName) != NULL;
        }
        cmdOffset += cmdsize;
    }
    return NO;
}

// Walk the target's vm regions with the task port and test every low-address
// region start for a Mach-O dylib whose install name matches (port of
// ff_scan_vmmap_for_module, region walk instead of vm_map entries — no kernel
// struct offsets, works across the supported version matrix).
- (uint64_t)scanForImageNamed:(const char *)imageName
{
    uint64_t found = 0;
    int checked = 0;
    mach_vm_address_t address = kImageRegionLow;
    while (address < kImageRegionHigh) {
        mach_vm_size_t size = 0;
        natural_t depth = 0;
        struct vm_region_submap_info_64 info;
        mach_msg_type_number_t count = VM_REGION_SUBMAP_INFO_COUNT_64;
        kern_return_t kr = mach_vm_region_recurse(self.taskPort, &address, &size, &depth,
                                                  (vm_region_recurse_info_t)&info, &count);
        if (kr != KERN_SUCCESS) break;
        if (info.is_submap) {
            depth++;
            address += size;
            continue;
        }
        if ((info.protection & VM_PROT_READ) && (info.protection & VM_PROT_EXECUTE)) {
            checked++;
            if (checked > 6000) break;
            if ([self regionIsImageNamed:(uint64_t)address imageName:imageName]) {
                found = (uint64_t)address;
                break;
            }
        }
        address += size;
    }
    DOKRWLog(@"ff: region scan: %d candidates checked, UnityFramework found=0x%llx",
             checked, (unsigned long long)found);
    return found;
}

// ------------------------------------------------------------------ attach

- (NSError *)attachWithError:(NSError **)error
{
    if (self.attached) return nil;

    DOJailbreaker *krw = [DOJailbreaker sharedInstance];
    if (!krw.kernelRWReady) {
        if (error) *error = [NSError errorWithDomain:@"DOFreeFireBridge" code:1
            userInfo:@{NSLocalizedDescriptionKey : @"Kernel R/W required. Get kernel R/W first."}];
        return *error;
    }

    DOKRWLog(@"ff: attach requested");

    pid_t pid = [self findFreeFirePid];
    if (pid <= 0) {
        if (error) *error = [NSError errorWithDomain:@"DOFreeFireBridge" code:2
            userInfo:@{NSLocalizedDescriptionKey : @"FreeFire process not found. Launch the game and try again."}];
        return *error;
    }
    DOKRWLog(@"ff: found FreeFire pid=%d", pid);

    // Zero the target's extmod counters first so kernel task surgery does not
    // accumulate on the game side, then take the real task port. Finally zero
    // our own counters, which task_for_pid bumps on the caller.
    BOOL zeroed = [krw zeroExtmodStatisticsForPid:pid];
    DOKRWLog(@"ff: extmod zero target=%@", zeroed ? @"yes" : @"no");

    mach_port_t port = MACH_PORT_NULL;
    kern_return_t kr = task_for_pid(mach_task_self(), pid, &port);
    if (kr != KERN_SUCCESS || port == MACH_PORT_NULL) {
        if (error) *error = [NSError errorWithDomain:@"DOFreeFireBridge" code:3
            userInfo:@{NSLocalizedDescriptionKey :
                       [NSString stringWithFormat:@"task_for_pid(%d) failed: %d (%s)", pid, kr, mach_error_string(kr)]}];
        return *error;
    }
    self.taskPort = port;
    self.attachedPid = pid;
    DOKRWLog(@"ff: task port acquired pid=%d port=%d", pid, port);

    BOOL selfZeroed = [krw zeroExtmodStatisticsForPid:getpid()];
    DOKRWLog(@"ff: extmod zero self=%@", selfZeroed ? @"yes" : @"no");

    uint64_t base = [self scanForImageNamed:"UnityFramework"];
    if (base == 0) {
        mach_port_deallocate(mach_task_self(), port);
        self.taskPort = MACH_PORT_NULL;
        self.attachedPid = 0;
        if (error) *error = [NSError errorWithDomain:@"DOFreeFireBridge" code:4
            userInfo:@{NSLocalizedDescriptionKey : @"UnityFramework base not found in FreeFire regions."}];
        return *error;
    }

    self.unityBase = base;
    self.attached = YES;
    DOKRWLog(@"ff: attached pid=%d UnityFramework base=0x%llx", pid, (unsigned long long)base);

    [[NSNotificationCenter defaultCenter] postNotificationName:DOFreeFireBridgeAttachDidChangeNotification object:self];
    return nil;
}

- (void)detach
{
    if (!self.attached && self.taskPort == MACH_PORT_NULL) return;
    DOKRWLog(@"ff: detach pid=%d", self.attachedPid);

    if (self.taskPort != MACH_PORT_NULL) {
        mach_port_deallocate(mach_task_self(), self.taskPort);
        self.taskPort = MACH_PORT_NULL;
    }
    self.attached = NO;
    self.attachedPid = 0;
    self.unityBase = 0;

    [[NSNotificationCenter defaultCenter] postNotificationName:DOFreeFireBridgeAttachDidChangeNotification object:self];
}

@end
