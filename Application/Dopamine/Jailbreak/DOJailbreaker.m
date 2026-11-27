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
#import <sys/socket.h>
#import <sys/un.h>
#import <pthread.h>
#import <fcntl.h>
#import <errno.h>
#import <stdint.h>
#import <dispatch/dispatch.h>
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
#import <libjailbreak/codesign.h>
#import <libjailbreak/trustcache.h>
#import <libjailbreak/trustcache_fs.h>
#import <libjailbreak/jbserver_boomerang.h>
#import <libjailbreak/signatures.h>
#import <libjailbreak/jbclient_xpc.h>
#import "../LaraPersistence/persistence.h"
#import "../Exploits/ClearSword/exploit/krw.h"
#import <libjailbreak/jbclient_mach.h>
#import <libjailbreak/basebin_gen.h>
#import <CoreServices/LSApplicationProxy.h>
#import <UIKit/UIKit.h>
#import <sys/proc.h>
#import <libproc.h>
#import "DOPreferenceManager.h"

int setBasebinDependency(bool present);
int randomizeAndLoadBasebinTrustcache(const char* basebinPath);
bool otherJailbreakActived(bool postexploit);
int posix_spawnattr_set_registered_ports_np(posix_spawnattr_t * __restrict attr, mach_port_t portarray[], uint32_t count);
#define kCFPreferencesNoContainer CFSTR("kCFPreferencesNoContainer")
void _CFPreferencesSetValueWithContainer(CFStringRef key, CFPropertyListRef value, CFStringRef applicationID, CFStringRef userName, CFStringRef hostName, CFStringRef containerPath);
Boolean _CFPreferencesSynchronizeWithContainer(CFStringRef applicationID, CFStringRef userName, CFStringRef hostName, CFStringRef containerPath);
CFArrayRef _CFPreferencesCopyKeyListWithContainer(CFStringRef applicationID, CFStringRef userName, CFStringRef hostName, CFStringRef containerPath);
CFDictionaryRef _CFPreferencesCopyMultipleWithContainer(CFArrayRef keysToFetch, CFStringRef applicationID, CFStringRef userName, CFStringRef hostName, CFStringRef containerPath);
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
    JBErrorCodeFailedGetRoot                 = -7,
    JBErrorCodeFailedUnsandbox               = -8,
    JBErrorCodeFailedPlatformize             = -9,
    JBErrorCodeFailedBasebinTrustcache       = -10,
    JBErrorCodeFailedLaunchdInjection        = -11,
    JBErrorCodeFailedInitProtection          = -12,
    JBErrorCodeFailedInitFakeLib             = -13,
    JBErrorCodeFailedDuplicateApps           = -14,
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
        fallback = [dir stringByAppendingPathComponent:@"FFKRW.log"];
    });
    return fallback;
}

static void DOKRWWriteState(NSString *uuid, BOOL ran, BOOL started)
{
    NSString *content = [NSString stringWithFormat:@"boot=%@\nran=%d\nstarted=%d\n", uuid ?: @"?", ran, started];
    NSArray<NSString *> *paths = @[
        @"/var/mobile/Documents/FFKRW.state",
        @"/var/mobile/Library/Logs/FFKRW.state",
        [DOKRWLogFallbackPath().stringByDeletingLastPathComponent stringByAppendingPathComponent:@"FFKRW.state"],
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
        @"/var/mobile/Documents/FFKRW.log",
        @"/var/mobile/Library/Logs/FFKRW.log",
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
- (NSError *)obtainKernelRWInProcess;
@end

#pragma mark - Persistent kernel helper

#define DOKRW_HELPER_MAGIC 0x4B525731u

enum {
    DOKRWHelperOpStatus = 1,
    DOKRWHelperOpZeroExtmod = 2,
    DOKRWHelperOpKread = 3,
    DOKRWHelperOpKwrite = 4,
};

typedef struct {
    uint32_t magic;
    uint32_t op;
    int32_t pid;
    uint32_t size;
    uint64_t addr;
    uint8_t data[0x1000];
} DOKRWHelperRequest;

typedef struct {
    uint32_t magic;
    int32_t status;
    uint32_t size;
    int32_t ready;
    uint32_t kcall;
    uint32_t extmod;
    uint64_t base;
    uint64_t slide;
    uint8_t data[0x1000];
} DOKRWHelperResponse;

static int gDOKRWHelperSocket = -1;
static pid_t gDOKRWHelperPid = 0;
static BOOL gDOKRWHelperActive = NO;
static volatile int gDOKRWHelperReady = 0;
static uint64_t gDOKRWHelperBase = 0;
static uint64_t gDOKRWHelperSlide = 0;
static BOOL gDOKRWHelperKcall = NO;
static uint32_t gDOKRWHelperExtmod = 0;
static uint32_t gDOKRWExtmodOffset = 0;
static pthread_mutex_t gDOKRWHelperLock = PTHREAD_MUTEX_INITIALIZER;

static NSString *DOKRWHelperSocketPath(void)
{
    return @"/tmp/FFKRW.sock";
}

static void DOKRWHelperResetConnection(void)
{
    if (gDOKRWHelperSocket >= 0) {
        close(gDOKRWHelperSocket);
        gDOKRWHelperSocket = -1;
    }
    gDOKRWHelperActive = NO;
    gDOKRWHelperReady = 0;
}

static int DOKRWHelperConnect(void)
{
    if (gDOKRWHelperSocket >= 0) return 0;
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) return -1;
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, DOKRWHelperSocketPath().fileSystemRepresentation, sizeof(addr.sun_path) - 1);
    if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
        close(fd);
        return -1;
    }
    gDOKRWHelperSocket = fd;
    gDOKRWHelperActive = YES;
    return 0;
}

static int DOKRWHelperSend(DOKRWHelperRequest *request, DOKRWHelperResponse *response)
{
    pthread_mutex_lock(&gDOKRWHelperLock);
    if (gDOKRWHelperSocket < 0) {
        pthread_mutex_unlock(&gDOKRWHelperLock);
        return -1;
    }
    ssize_t sent = send(gDOKRWHelperSocket, request, sizeof(*request), 0);
    ssize_t received = -1;
    if (sent == (ssize_t)sizeof(*request)) {
        received = recv(gDOKRWHelperSocket, response, sizeof(*response), MSG_WAITALL);
    }
    if (sent != (ssize_t)sizeof(*request) || received != (ssize_t)sizeof(*response)) {
        DOKRWHelperResetConnection();
        pthread_mutex_unlock(&gDOKRWHelperLock);
        return -1;
    }
    pthread_mutex_unlock(&gDOKRWHelperLock);
    return response->status;
}

static int DOKRWChildZeroExtmod(pid_t pid)
{
    if (!gDOKRWExtmodOffset) return -1;
    uint64_t proc = proc_find(pid);
    if (!proc) return -1;
    uint64_t task = proc_task(proc);
    proc_rele(proc);
    if (!task) return -1;
    uint64_t zeros[6] = {0};
    return gPrimitives.kwritebuf(task + gDOKRWExtmodOffset, zeros, sizeof(zeros));
}

static void DOKRWHelperServeForked(int listenFD)
{
    while (1) {
        int fd = accept(listenFD, NULL, NULL);
        if (fd < 0) continue;
        DOKRWHelperRequest req;
        while (read(fd, &req, sizeof(req)) == (ssize_t)sizeof(req)) {
            DOKRWHelperResponse resp;
            memset(&resp, 0, sizeof(resp));
            resp.magic = DOKRW_HELPER_MAGIC;
            resp.ready = 1;
            resp.base = gSystemInfo.kernelConstant.base;
            resp.slide = gSystemInfo.kernelConstant.slide;
            resp.kcall = gPrimitives.kcall != NULL;
            resp.extmod = gDOKRWExtmodOffset;
            switch (req.op) {
                case DOKRWHelperOpStatus:
                    resp.status = 0;
                    break;
                case DOKRWHelperOpZeroExtmod:
                    resp.status = DOKRWChildZeroExtmod(req.pid);
                    break;
                case DOKRWHelperOpKread:
                    if (req.size <= sizeof(resp.data)) {
                        resp.size = req.size;
                        resp.status = gPrimitives.kreadbuf ? gPrimitives.kreadbuf(req.addr, resp.data, req.size) : -1;
                    } else {
                        resp.status = -1;
                    }
                    break;
                case DOKRWHelperOpKwrite:
                    if (req.size <= sizeof(req.data)) {
                        resp.status = gPrimitives.kwritebuf ? gPrimitives.kwritebuf(req.addr, req.data, req.size) : -1;
                    } else {
                        resp.status = -1;
                    }
                    break;
                default:
                    resp.status = -1;
                    break;
            }
            write(fd, &resp, sizeof(resp));
        }
        close(fd);
    }
}

// The exploit (including Titan's PPL bypass) needs the app's UIApplication and
// must run in the app process. After it succeeds, fork a child that inherits
// the ready primitives and serves them over the socket. The child only uses
// ClearSword's socket-based kread/kwrite and proc_find/proc_task, so it does
// not touch ObjC or libdispatch after fork.
static int DOKRWHelperFork(void)
{
    DOJailbreaker *jb = [DOJailbreaker sharedInstance];
    if (!jb.kernelRWReady) {
        DOKRWLog(@"helper: fork skipped (kernel R/W not ready)");
        return -1;
    }
    [jb resolveExtmodOffset];
    gDOKRWExtmodOffset = jb.extmodOffset;
    if (!gDOKRWExtmodOffset) DOKRWLog(@"helper: extmod offset unresolved");

    NSString *sock = DOKRWHelperSocketPath();
    unlink(sock.fileSystemRepresentation);
    int listenFD = socket(AF_UNIX, SOCK_STREAM, 0);
    if (listenFD < 0) {
        DOKRWLog(@"helper: socket failed errno=%d %s", errno, strerror(errno));
        return -1;
    }
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, sock.fileSystemRepresentation, sizeof(addr.sun_path) - 1);
    if (bind(listenFD, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
        DOKRWLog(@"helper: bind failed errno=%d %s path=%@", errno, strerror(errno), sock);
        close(listenFD);
        return -1;
    }
    if (listen(listenFD, 4) != 0) {
        DOKRWLog(@"helper: listen failed errno=%d %s", errno, strerror(errno));
        close(listenFD);
        return -1;
    }

    gDOKRWHelperReady = 1;
    pid_t pid = fork();
    if (pid < 0) {
        DOKRWLog(@"helper: fork failed errno=%d %s", errno, strerror(errno));
        gDOKRWHelperReady = 0;
        close(listenFD);
        return -1;
    }
    if (pid == 0) {
        setsid();
        signal(SIGHUP, SIG_IGN);
        signal(SIGPIPE, SIG_IGN);
        DOKRWHelperServeForked(listenFD);
        _exit(0);
    }

    gDOKRWHelperReady = 0;
    close(listenFD);
    gDOKRWHelperPid = pid;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:pid forKey:@"DOKRWHelperPid"];
    NSString *boot = DOKRWCurrentBootSessionUUID();
    if (boot) [defaults setObject:boot forKey:@"DOKRWHelperBoot"];
    [defaults synchronize];
    DOKRWLog(@"helper: forked pid=%d socket=%@", pid, sock);
    return 0;
}

static int DOKRWHelperSpawn(void)
{
    NSString *exe = [[NSBundle mainBundle] executablePath];
    NSString *sock = DOKRWHelperSocketPath();
    if (!exe || !sock) return -1;

    posix_spawnattr_t attr;
    posix_spawnattr_init(&attr);
    posix_spawnattr_setflags(&attr, POSIX_SPAWN_SETSID);

    char *argv[] = {
        (char *)exe.fileSystemRepresentation,
        "krw-helper",
        (char *)sock.fileSystemRepresentation,
        NULL
    };

    pid_t pid = 0;
    int rc = posix_spawn(&pid, exe.fileSystemRepresentation, NULL, &attr, argv, environ);
    posix_spawnattr_destroy(&attr);
    if (rc != 0) {
        DOKRWLog(@"helper: spawn failed %d", rc);
        return -1;
    }

    gDOKRWHelperPid = pid;
    gDOKRWHelperReady = 0;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:pid forKey:@"DOKRWHelperPid"];
    NSString *boot = DOKRWCurrentBootSessionUUID();
    if (boot) [defaults setObject:boot forKey:@"DOKRWHelperBoot"];
    [defaults synchronize];
    DOKRWLog(@"helper: spawned pid=%d socket=%@", pid, sock);
    return 0;
}

static BOOL DOKRWHelperProcessAlive(pid_t pid)
{
    if (pid <= 0) return NO;
    if (kill(pid, 0) != 0) return NO;
    char name[64] = {0};
    if (proc_name(pid, name, sizeof(name)) > 0) {
        return strcmp(name, "FFKRW") == 0;
    }
    return NO;
}

static int DOKRWHelperWaitReady(int timeoutMs)
{
    int attempts = timeoutMs / 100;
    for (int i = 0; i < attempts; i++) {
        if (gDOKRWHelperPid > 0) {
            int status = 0;
            pid_t waited = waitpid(gDOKRWHelperPid, &status, WNOHANG);
            if (waited == gDOKRWHelperPid) {
                DOKRWLog(@"helper: exited status=0x%x", status);
                gDOKRWHelperPid = 0;
                return -1;
            }
            if (waited == -1 && errno == ECHILD && !DOKRWHelperProcessAlive(gDOKRWHelperPid) && DOKRWHelperConnect() != 0) {
                DOKRWLog(@"helper: pid %d exited before serving", gDOKRWHelperPid);
                gDOKRWHelperPid = 0;
                return -1;
            }
        }
        if (DOKRWHelperConnect() == 0) {
            DOKRWHelperRequest req;
            memset(&req, 0, sizeof(req));
            req.magic = DOKRW_HELPER_MAGIC;
            req.op = DOKRWHelperOpStatus;
            DOKRWHelperResponse resp;
            memset(&resp, 0, sizeof(resp));
            if (DOKRWHelperSend(&req, &resp) == 0) {
                gDOKRWHelperReady = resp.ready;
                gDOKRWHelperBase = resp.base;
                gDOKRWHelperSlide = resp.slide;
                gDOKRWHelperKcall = resp.kcall != 0;
                gDOKRWHelperExtmod = resp.extmod;
                if (resp.ready == 1) return 0;
                if (resp.ready < 0) return -1;
            }
        }
        usleep(100 * 1000);
    }
    return -1;
}

static BOOL DOKRWHelperStartIfNeeded(void)
{
    if (gDOKRWHelperActive && gDOKRWHelperReady == 1) {
        DOKRWHelperRequest req;
        memset(&req, 0, sizeof(req));
        req.magic = DOKRW_HELPER_MAGIC;
        req.op = DOKRWHelperOpStatus;
        DOKRWHelperResponse resp;
        memset(&resp, 0, sizeof(resp));
        if (DOKRWHelperSend(&req, &resp) == 0 && resp.ready == 1) {
            gDOKRWHelperBase = resp.base;
            gDOKRWHelperSlide = resp.slide;
            gDOKRWHelperKcall = resp.kcall != 0;
            gDOKRWHelperExtmod = resp.extmod;
            return YES;
        }
        DOKRWHelperResetConnection();
    }

    if (DOKRWHelperConnect() == 0) {
        return DOKRWHelperWaitReady(60000) == 0;
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *currentBoot = DOKRWCurrentBootSessionUUID();
    NSString *helperBoot = [defaults stringForKey:@"DOKRWHelperBoot"];
    if (!currentBoot || !helperBoot || ![currentBoot isEqualToString:helperBoot]) {
        [defaults removeObjectForKey:@"DOKRWHelperPid"];
        [defaults synchronize];
    }
    pid_t helperPid = (pid_t)[defaults integerForKey:@"DOKRWHelperPid"];
    if (helperPid > 0) {
        int status = 0;
        if (waitpid(helperPid, &status, WNOHANG) == helperPid) {
            helperPid = 0;
        }
    }
    if (helperPid > 0 && DOKRWHelperProcessAlive(helperPid)) {
        return DOKRWHelperWaitReady(60000) == 0;
    }

    if (DOKRWHelperSpawn() != 0) return NO;
    return DOKRWHelperWaitReady(60000) == 0;
}

static void DOKRWHelperServe(int listenFD)
{
    while (1) {
        int fd = accept(listenFD, NULL, NULL);
        if (fd < 0) {
            if (errno == EINTR) continue;
            break;
        }
        DOKRWHelperRequest req;
        while (recv(fd, &req, sizeof(req), MSG_WAITALL) == (ssize_t)sizeof(req)) {
            DOKRWHelperResponse resp;
            memset(&resp, 0, sizeof(resp));
            resp.magic = DOKRW_HELPER_MAGIC;
            resp.ready = (int32_t)gDOKRWHelperReady;
            resp.base = gSystemInfo.kernelConstant.base;
            resp.slide = gSystemInfo.kernelConstant.slide;
            resp.kcall = gPrimitives.kcall != NULL;
            resp.extmod = [[DOJailbreaker sharedInstance] extmodOffset];
            switch (req.op) {
                case DOKRWHelperOpStatus:
                    resp.status = 0;
                    break;
                case DOKRWHelperOpZeroExtmod:
                    resp.status = [[DOJailbreaker sharedInstance] zeroExtmodStatisticsForPid:req.pid] ? 0 : -1;
                    break;
                case DOKRWHelperOpKread:
                    if (req.size <= sizeof(resp.data)) {
                        resp.size = req.size;
                        resp.status = [[DOJailbreaker sharedInstance] kreadbuf:req.addr to:resp.data size:req.size];
                    } else {
                        resp.status = -1;
                    }
                    break;
                case DOKRWHelperOpKwrite:
                    if (req.size <= sizeof(req.data)) {
                        resp.status = [[DOJailbreaker sharedInstance] kwritebuf:req.addr from:req.data size:req.size];
                    } else {
                        resp.status = -1;
                    }
                    break;
                default:
                    resp.status = -1;
                    break;
            }
            send(fd, &resp, sizeof(resp), 0);
        }
        close(fd);
    }
}

int DOKRWHelperMain(const char *socketPath)
{
    DOKRWLog(@"helper: main start pid=%d socket=%s", getpid(), socketPath);
    int sid = setsid();
    DOKRWLog(@"helper: setsid=%d errno=%d", sid, errno);
    signal(SIGHUP, SIG_IGN);

    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    DOKRWLog(@"helper: socket=%d errno=%d", fd, errno);
    if (fd < 0) return 1;
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, socketPath, sizeof(addr.sun_path) - 1);
    unlink(socketPath);
    int br = bind(fd, (struct sockaddr *)&addr, sizeof(addr));
    DOKRWLog(@"helper: bind=%d errno=%d", br, errno);
    if (br != 0) {
        close(fd);
        return 1;
    }
    int lr = listen(fd, 4);
    DOKRWLog(@"helper: listen=%d errno=%d", lr, errno);
    if (lr != 0) {
        close(fd);
        return 1;
    }
    DOKRWLog(@"helper: listening on %s", socketPath);

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *error = [[DOJailbreaker sharedInstance] obtainKernelRWInProcess];
        gDOKRWHelperReady = error ? -1 : 1;
        DOKRWLog(@"helper: %@", error ? error.localizedDescription : @"kernel R/W ready");
        if (!error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                for (UIWindow *window in [UIApplication sharedApplication].windows) {
                    if (window.rootViewController) {
                        window.hidden = YES;
                        window.rootViewController = nil;
                    }
                }
            });
        }
    });
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        DOKRWHelperServe(fd);
    });

    dispatch_main();
    return 0;
}

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
    if ([[DOEnvironmentManager sharedManager] isJailbroken]) return YES;
    return _kernelRWReady;
}

- (BOOL)isJailbroken
{
    return [[DOEnvironmentManager sharedManager] isJailbroken];
}

- (BOOL)exploitRanThisBoot
{
    NSString *currentBoot = DOKRWCurrentBootSessionUUID();
    if (!currentBoot) return NO;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *lastBoot = [defaults stringForKey:@"DOKRWBootSessionUUID"];
    return lastBoot && [currentBoot isEqualToString:lastBoot] && [defaults boolForKey:@"DOKRWExploitRan"];
}

- (BOOL)exploitStartedThisBoot
{
    NSString *currentBoot = DOKRWCurrentBootSessionUUID();
    if (!currentBoot) return NO;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *lastBoot = [defaults stringForKey:@"DOKRWBootSessionUUID"];
    return lastBoot && [currentBoot isEqualToString:lastBoot] && [defaults boolForKey:@"DOKRWExploitStarted"];
}

- (BOOL)restoreKernelRWFromHelper
{
    if (DOKRWHelperConnect() != 0) return NO;
    DOKRWHelperRequest req;
    memset(&req, 0, sizeof(req));
    req.magic = DOKRW_HELPER_MAGIC;
    req.op = DOKRWHelperOpStatus;
    DOKRWHelperResponse resp;
    memset(&resp, 0, sizeof(resp));
    if (DOKRWHelperSend(&req, &resp) != 0 || resp.ready != 1) return NO;
    gDOKRWHelperActive = YES;
    gDOKRWHelperReady = 1;
    gDOKRWHelperBase = resp.base;
    gDOKRWHelperSlide = resp.slide;
    gDOKRWHelperKcall = resp.kcall != 0;
    gDOKRWHelperExtmod = resp.extmod;
    _kernelRWReady = YES;
    DOKRWLog(@"helper: restored base=0x%llx slide=0x%llx",
             (unsigned long long)resp.base, (unsigned long long)resp.slide);
    return YES;
}

- (uint64_t)kernelBase
{
    if (gDOKRWHelperActive) return gDOKRWHelperBase;
    return gSystemInfo.kernelConstant.base;
}

- (uint64_t)kernelSlide
{
    if (gDOKRWHelperActive) return gDOKRWHelperSlide;
    return gSystemInfo.kernelConstant.slide;
}

- (BOOL)isKcallAvailable
{
    if (gDOKRWHelperActive) return gDOKRWHelperKcall;
    return gPrimitives.kcall != NULL;
}

#pragma mark - Pipeline

- (NSError *)obtainKernelRW
{
    if ([self isJailbroken]) {
        _kernelRWReady = YES;
        DOKRWLog(@"obtainKernelRW: roothide jailbreak present");
        return nil;
    }
    if (!_kernelRWReady) {
        // Recovery on a fresh launch needs gSystemInfo populated (koffsetof)
        // before proc_self/RemoteCall can walk kernel structures.
        NSError *gatherError = [self gatherSystemInformation];
        if (gatherError) {
            DOKRWLog(@"obtainKernelRW: recovery patchfinding failed: %@", gatherError.localizedDescription);
            return gatherError;
        }
        lara_offsets_init();
        gPrimitives.kreadbuf = clearsword_kreadbuf;
        gPrimitives.kwritebuf = clearsword_kwritebuf;
        gPrimitives.krwMinSafeReadSize = 0x20;
        if (recover_krw_primitives()) {
            g_ctx.control_socket = control_socket;
            g_ctx.rw_socket = rw_socket;
            g_ctx.kernel_base = kernel_base;
            g_ctx.kernel_slide = kernel_slide;
            gSystemInfo.kernelConstant.base = kernel_base;
            gSystemInfo.kernelConstant.slide = kernel_slide;
            _kernelRWReady = YES;
            DOKRWLog(@"obtainKernelRW: recovered from launchd");
            return nil;
        }
    }
    if (_kernelRWReady) {
        DOKRWLog(@"obtainKernelRW: already ready");
        return nil;
    }
    if ([self exploitRanThisBoot]) {
        // Re-running ClearSword/Titan in the same boot corrupts kernel state and
        // panics (GFX NMI in backboardd). Once the exploit has run, the only way
        // back is recovery of the stashed sockets.
        DOKRWLog(@"obtainKernelRW: recovery failed and the exploit already ran this boot; refusing to re-run it");
        return [NSError errorWithDomain:JBErrorDomain
                                   code:JBErrorCodeFailedExploitation
                               userInfo:@{NSLocalizedDescriptionKey : @"Kernel R/W from this boot could not be recovered. Reboot the device and run it again."}];
    }
    NSError *error = [self obtainKernelRWInProcess];
    if (error) return error;
    _kernelRWReady = YES;
    control_socket = g_ctx.control_socket;
    rw_socket = g_ctx.rw_socket;
    kernel_base = g_ctx.kernel_base;
    kernel_slide = g_ctx.kernel_slide;
    lara_offsets_init();
    if (transfer_krw_to_launchd()) {
        DOKRWLog(@"obtainKernelRW: stashed to launchd");
    } else {
        DOKRWLog(@"obtainKernelRW: launchd stash failed");
    }
    DOKRWLog(@"obtainKernelRW: ready base=0x%llx slide=0x%llx",
             (unsigned long long)gSystemInfo.kernelConstant.base,
             (unsigned long long)gSystemInfo.kernelConstant.slide);
    return nil;
}


- (NSError *)obtainKernelRWInProcess
{
    @synchronized (self) {
        if (_kernelRWReady) return nil;

        NSString *currentBoot = DOKRWCurrentBootSessionUUID();
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *lastBoot = [defaults stringForKey:@"DOKRWBootSessionUUID"];
        BOOL ranThisBoot = [defaults boolForKey:@"DOKRWExploitRan"];
        BOOL startedThisBoot = [defaults boolForKey:@"DOKRWExploitStarted"];
        DOKRWLog(@"boot: uuid=%@ last=%@ ran=%d started=%d prefs=%@",
                 currentBoot ?: @"?", lastBoot ?: @"?", ranThisBoot, startedThisBoot,
                 [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"Preferences"]);
        DOKRWWriteState(currentBoot, ranThisBoot, startedThisBoot);
        if (currentBoot && (!lastBoot || ![currentBoot isEqualToString:lastBoot])) {
            [defaults setBool:NO forKey:@"DOKRWExploitRan"];
            [defaults setBool:NO forKey:@"DOKRWExploitStarted"];
            [defaults setObject:currentBoot forKey:@"DOKRWBootSessionUUID"];
            [defaults synchronize];
        }

        [defaults setBool:YES forKey:@"DOKRWExploitStarted"];
        [defaults synchronize];
        DOKRWWriteState(currentBoot, ranThisBoot, YES);

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
            [defaults setBool:YES forKey:@"DOKRWExploitStarted"];
            [defaults setObject:currentBoot forKey:@"DOKRWBootSessionUUID"];
            [defaults synchronize];
            DOKRWWriteState(currentBoot, YES, YES);
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
    NSArray<DOExploit *> *kernelExploits = [DOExploitManager sharedManager].orderedKernelExploits;
    DOExploit *pacBypass     = [DOExploitManager sharedManager].selectedPACBypass;
    DOExploit *pplBypass     = [DOExploitManager sharedManager].selectedPPLBypass;

    if (!kernelExploits.count) {
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

    DOExploit *kernelExploit = nil;
    for (DOExploit *candidate in kernelExploits) {
        DOKRWLog(@"exploit: trying kernel=%@ priority=%llu persistentTransport=%d",
                 candidate.displayName, (unsigned long long)candidate.priority, candidate.persistentTransport);
        [[DOUIManager sharedInstance] sendLog:[NSString stringWithFormat:DOLocalizedString(@"Exploiting Kernel (%@)"), candidate.name] debug:NO];
        if ([candidate load] != 0) {
            DOKRWLog(@"exploit: kernel=%@ failed to load: %s", candidate.displayName, dlerror() ?: "");
            continue;
        }
        if ([candidate run] != 0) {
            DOKRWLog(@"exploit: kernel=%@ failed to run, trying the next one", candidate.displayName);
            [candidate cleanup];
            continue;
        }
        kernelExploit = candidate;
        break;
    }
    if (!kernelExploit) {
        return [NSError errorWithDomain:JBErrorDomain code:JBErrorCodeFailedExploitation userInfo:@{NSLocalizedDescriptionKey:@"Failed to exploit kernel"}];
    }

    NSUserDefaults *exploitDefaults = [NSUserDefaults standardUserDefaults];
    [exploitDefaults setObject:(kernelExploit.displayName ?: @"") forKey:@"DOKRWLastKernelExploitName"];
    [exploitDefaults setObject:@(kernelExploit.persistentTransport) forKey:@"DOKRWLastKernelExploitResumable"];

    DOKRWLog(@"exploit: kernel=%@ pac=%@ ppl=%@", kernelExploit.displayName, pacBypass.displayName ?: @"none", pplBypass.displayName ?: @"none");

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
    if (gDOKRWHelperActive) {
        DOKRWHelperRequest req;
        memset(&req, 0, sizeof(req));
        req.magic = DOKRW_HELPER_MAGIC;
        req.op = DOKRWHelperOpKread;
        req.addr = addr;
        req.size = sizeof(uint64_t);
        DOKRWHelperResponse resp;
        memset(&resp, 0, sizeof(resp));
        if (DOKRWHelperSend(&req, &resp) != 0) return 0;
        uint64_t value = 0;
        memcpy(&value, resp.data, sizeof(value));
        return value;
    }
    return kread64(addr);
}

- (uint32_t)kread32:(uint64_t)addr
{
    if (gDOKRWHelperActive) {
        DOKRWHelperRequest req;
        memset(&req, 0, sizeof(req));
        req.magic = DOKRW_HELPER_MAGIC;
        req.op = DOKRWHelperOpKread;
        req.addr = addr;
        req.size = sizeof(uint32_t);
        DOKRWHelperResponse resp;
        memset(&resp, 0, sizeof(resp));
        if (DOKRWHelperSend(&req, &resp) != 0) return 0;
        uint32_t value = 0;
        memcpy(&value, resp.data, sizeof(value));
        return value;
    }
    return kread32(addr);
}

- (int)kreadbuf:(uint64_t)addr to:(void *)out size:(size_t)size
{
    if (gDOKRWHelperActive) {
        if (size > sizeof(((DOKRWHelperResponse *)0)->data)) return -1;
        DOKRWHelperRequest req;
        memset(&req, 0, sizeof(req));
        req.magic = DOKRW_HELPER_MAGIC;
        req.op = DOKRWHelperOpKread;
        req.addr = addr;
        req.size = (uint32_t)size;
        DOKRWHelperResponse resp;
        memset(&resp, 0, sizeof(resp));
        if (DOKRWHelperSend(&req, &resp) != 0) return -1;
        memcpy(out, resp.data, size);
        return 0;
    }
    return kreadbuf(addr, out, size);
}

- (int)kwrite64:(uint64_t)addr value:(uint64_t)value
{
    if (gDOKRWHelperActive) return [self kwritebuf:addr from:&value size:sizeof(value)];
    return kwrite64(addr, value);
}

- (int)kwrite32:(uint64_t)addr value:(uint32_t)value
{
    if (gDOKRWHelperActive) return [self kwritebuf:addr from:&value size:sizeof(value)];
    return kwrite32(addr, value);
}

- (int)kwritebuf:(uint64_t)addr from:(const void *)in size:(size_t)size
{
    if (gDOKRWHelperActive) {
        if (size > sizeof(((DOKRWHelperRequest *)0)->data)) return -1;
        DOKRWHelperRequest req;
        memset(&req, 0, sizeof(req));
        req.magic = DOKRW_HELPER_MAGIC;
        req.op = DOKRWHelperOpKwrite;
        req.addr = addr;
        req.size = (uint32_t)size;
        memcpy(req.data, in, size);
        DOKRWHelperResponse resp;
        memset(&resp, 0, sizeof(resp));
        return DOKRWHelperSend(&req, &resp);
    }
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
    { "20G75", 0x438 },
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
    if (gDOKRWHelperActive) return gDOKRWHelperExtmod;
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
    if (gDOKRWHelperActive) {
        DOKRWHelperRequest req;
        memset(&req, 0, sizeof(req));
        req.magic = DOKRW_HELPER_MAGIC;
        req.op = DOKRWHelperOpZeroExtmod;
        req.pid = pid;
        DOKRWHelperResponse resp;
        memset(&resp, 0, sizeof(resp));
        return DOKRWHelperSend(&req, &resp) == 0;
    }
    return [self zeroExtmodStatisticsForTask:[self kernelTaskForPid:pid]];
}


#pragma mark - roothide persistence

- (NSError *)elevatePrivileges
{
    uint64_t proc = proc_self();
    uint64_t ucred = proc_ucred(proc);
    
    // Get uid 0
    kwrite32(proc + koffsetof(proc, svuid), 0);
    kwrite32(ucred + koffsetof(ucred, svuid), 0);
    kwrite32(ucred + koffsetof(ucred, ruid), 0);
    kwrite32(ucred + koffsetof(ucred, uid), 0);
    
    // Get gid 0
    kwrite32(proc + koffsetof(proc, svgid), 0);
    kwrite32(ucred + koffsetof(ucred, rgid), 0);
    kwrite32(ucred + koffsetof(ucred, svgid), 0);
    kwrite32(ucred + koffsetof(ucred, groups), 0);
    
    // Add P_SUGID
    uint32_t flag = kread32(proc + koffsetof(proc, flag));
    if ((flag & P_SUGID) != 0) {
        flag &= P_SUGID;
        kwrite32(proc + koffsetof(proc, flag), flag);
    }
    
    if (getuid() != 0) return [NSError errorWithDomain:JBErrorDomain code:JBErrorCodeFailedGetRoot userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Failed to get root, uid still %d", getuid()]}];
    if (getgid() != 0) return [NSError errorWithDomain:JBErrorDomain code:JBErrorCodeFailedGetRoot userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Failed to get root, gid still %d", getgid()]}];
    
    // Unsandbox
    uint64_t label = kread_ptr(ucred + koffsetof(ucred, label));
    mac_label_set(label, 1, -1);
    NSError *error = nil;
    [[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/var" error:&error];
    if (error) return [NSError errorWithDomain:JBErrorDomain code:JBErrorCodeFailedUnsandbox userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Failed to unsandbox, /var does not seem accessible (%s)", error.description.UTF8String]}];
    setenv("HOME", "/var/root", true);
    setenv("CFFIXED_USER_HOME", "/var/root", true);
    setenv("TMPDIR", "/var/tmp", true);
    
    // FUCKING dirhelper caches the temporary path
    // So we have to do userland patchfinding to find the fucking string and overwrite it
    /*char **pain = NULL;
    uint32_t *dirhelperData = (uint32_t *)_dirhelper;
    for (int i = 0; i < 100; i++) {
        arm64_register destinationReg;
        uint64_t imm = 0;
        if (arm64_dec_ldr_imm(dirhelperData[i], &destinationReg, NULL, &imm, NULL, NULL) == 0) {
            if (ARM64_REG_GET_NUM(destinationReg) == 1) {
                uint32_t *adrpAddr = &dirhelperData[i - 1];
                uint64_t adrpTarget = 0;
                uint32_t adrpInst = *adrpAddr;
                if (arm64_dec_adr_p(adrpInst, (uint64_t)adrpAddr, &adrpTarget, NULL, NULL) == 0) {
                    pain = (char **)(uint64_t)(adrpTarget + imm);
                    break;
                }
            }
        }
    }
    *pain = strdup("/var/tmp");*/
    
    // Get CS_PLATFORM_BINARY
    proc_csflags_set(proc, CS_PLATFORM_BINARY);
    uint32_t csflags;
    csops(getpid(), CS_OPS_STATUS, &csflags, sizeof(csflags));
    if (!(csflags & CS_PLATFORM_BINARY)) return [NSError errorWithDomain:JBErrorDomain code:JBErrorCodeFailedPlatformize userInfo:@{NSLocalizedDescriptionKey:@"Failed to get CS_PLATFORM_BINARY"}];
    
/**************************** roothide specific ********************/
    proc_csflags_set(proc, CS_INSTALLER);

    if(otherJailbreakActived(true)) {
        return [NSError errorWithDomain:@"RootHide" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Your device currently has another jailbreak activated, please reboot device."}];
    }
/***********************************************************************/
    
    return nil;
}

- (NSError *)showNonDefaultSystemApps
{
    _CFPreferencesSetValueWithContainer(CFSTR("SBShowNonDefaultSystemApps"), kCFBooleanTrue, CFSTR("com.apple.springboard"), CFSTR("mobile"), kCFPreferencesAnyHost, kCFPreferencesNoContainer);
    _CFPreferencesSynchronizeWithContainer(CFSTR("com.apple.springboard"), CFSTR("mobile"), kCFPreferencesAnyHost, kCFPreferencesNoContainer);
    return nil;
}

- (NSError *)ensureDevModeEnabled
{
    if (@available(iOS 16.0, *)) {
        uint64_t developer_mode_storage = 0;
        if (ksymbol(developer_mode_enabled)) {
            developer_mode_storage = kread64(ksymbol(developer_mode_enabled));
        }
        else if (ksymbol_txm(txm_developer_mode_storage)) {
            developer_mode_storage = ksymbol_txm(txm_developer_mode_storage);
        }

        if (developer_mode_storage) {
            kwrite8(developer_mode_storage, 1);
        }
    }
    return nil;
}

/*
- (NSError *)loadBasebinTrustcache
{
    trustcache_file_v1 *basebinTcFile = NULL;
    if (trustcache_file_build_from_path(JBROOT_PATH("/basebin/basebin.tc"), &basebinTcFile) == 0) {
        int r = trustcache_file_upload_with_uuid(basebinTcFile, BASEBIN_TRUSTCACHE_UUID);
        free(basebinTcFile);
        if (r != 0) return [NSError errorWithDomain:JBErrorDomain code:JBErrorCodeFailedBasebinTrustcache userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Failed to upload BaseBin trustcache: %d", r]}];
        return nil;
    }
    return [NSError errorWithDomain:JBErrorDomain code:JBErrorCodeFailedBasebinTrustcache userInfo:@{NSLocalizedDescriptionKey : @"Failed to load BaseBin trustcache"}];
}
*/
/************************ roothide specific ******************/
- (NSError *)loadBasebinTrustcache
{
    int ret = randomizeAndLoadBasebinTrustcache(JBROOT_PATH("/basebin/"));
    if (ret != 0) {
        return [NSError errorWithDomain:JBErrorDomain code:JBErrorCodeFailedBasebinTrustcache 
            userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Failed to load BaseBin trustcache: %d", ret]}];
    }
    return nil;
}
/************************ roothide specific ******************/


struct boomerang_info {
    mach_port_t serverPort;
    dispatch_semaphore_t boomerangDone;
};

void *boomerang_server(struct boomerang_info *info)
{
    while (true) {
        xpc_object_t xdict = nil;
        if (!xpc_pipe_receive(info->serverPort, &xdict)) {
            if (jbserver_received_boomerang_xpc_message(&gBoomerangServer, xdict) == JBS_BOOMERANG_DONE) {
                dispatch_semaphore_signal(info->boomerangDone);
                break;
            }
        }
    }
    return NULL;
}

- (NSError *)injectLaunchdHook
{
    // Host a boomerang server that will be used by launchdhook to get the jailbreak primitives from this app
    mach_port_t serverPort = MACH_PORT_NULL;
    mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &serverPort);
    mach_port_insert_right(mach_task_self(), serverPort, serverPort, MACH_MSG_TYPE_MAKE_SEND);
    
    struct boomerang_info info;
    info.serverPort = serverPort;
    info.boomerangDone = dispatch_semaphore_create(0);
    
    pthread_t boomerangThread;
    pthread_create(&boomerangThread, NULL, (void *(*)(void *))boomerang_server, &info);
    pthread_detach(boomerangThread);

    // Stash port to server in launchd's initPorts[2]
    // Since we don't have the neccessary entitlements, we need to do it over jbctl
    posix_spawnattr_t attr;
    posix_spawnattr_init(&attr);
    posix_spawnattr_set_registered_ports_np(&attr, (mach_port_t[]){MACH_PORT_NULL, MACH_PORT_NULL, serverPort}, 3);
    pid_t spawnedPid = 0;
    const char *jbctlPath = JBROOT_PATH("/basebin/jbctl");
    int spawnError = posix_spawn(&spawnedPid, jbctlPath, NULL, &attr, (char *const *)(const char *[]){ jbctlPath, "internal", "launchd_stash_port", NULL }, NULL);
    if (spawnError != 0) {
        return [NSError errorWithDomain:JBErrorDomain code:JBErrorCodeFailedLaunchdInjection userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Spawning jbctl failed with error code %d", spawnError]}];
    }
    posix_spawnattr_destroy(&attr);
    int status = 0;
    do {
        if (waitpid(spawnedPid, &status, 0) == -1) {
            return [NSError errorWithDomain:JBErrorDomain code:JBErrorCodeFailedLaunchdInjection userInfo:@{NSLocalizedDescriptionKey : @"Waiting for jbctl failed"}];
        }
    } while (!WIFEXITED(status) && !WIFSIGNALED(status));

    // Inject launchdhook.dylib into launchd via opainject
    int r = exec_cmd(JBROOT_PATH("/basebin/opainject"), "1", JBROOT_PATH("/basebin/launchdhook.dylib"), NULL);
    if (r != 0) {
        return [NSError errorWithDomain:JBErrorDomain code:JBErrorCodeFailedLaunchdInjection userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"opainject failed with error code %d", r]}];
    }

    // Wait for everything to finish
    dispatch_semaphore_wait(info.boomerangDone, DISPATCH_TIME_FOREVER);
    mach_port_deallocate(mach_task_self(), serverPort);

    return nil;
}

- (NSError *)removeJailbreak
{
    if (@available(iOS 18.0, *)) {
        // On iOS 18+, jailbreak apps persist on the home screen even after a reboot into unjailbroken state
        // So we need to remove them from icon cache before deleting the bootstrap
        [[DOUIManager sharedInstance] sendLog:DOLocalizedString(@"Rebuilding Icon Cache") debug:NO];
        [[DOEnvironmentManager sharedManager] rebuildIconCache];
    }

    NSError *err;
    [[DOUIManager sharedInstance] sendLog:DOLocalizedString(@"Removing Jailbreak") debug:NO];
    err = [[DOEnvironmentManager sharedManager] deleteBootstrap];
    if (err) return err;

    return nil;
}

- (NSError *)finalizeBootstrapIfNeeded
{
    return [[DOEnvironmentManager sharedManager] finalizeBootstrap];
}

- (NSError *)cleanUpPostExploitation
{
    if (@available(iOS 17.0, *)) {
        uint64_t proc = proc_self();
        uint64_t ucred = proc_ucred(proc);

        // Get uid 0
        kwrite32(ucred + koffsetof(ucred, svuid), 501);
        kwrite32(ucred + koffsetof(ucred, ruid), 501);
        kwrite32(ucred + koffsetof(ucred, uid), 501);
        
        // Get gid 0
        kwrite32(ucred + koffsetof(ucred, rgid), 501);
        kwrite32(ucred + koffsetof(ucred, svgid), 501);
        kwrite32(ucred + koffsetof(ucred, groups), 501);
    }

    return nil;
}

- (void)runWithError:(NSError **)errOut didRemoveJailbreak:(BOOL*)didRemove showLogs:(BOOL *)showLogs
{
    if ([self isJailbroken]) { if (errOut) *errOut = nil; return; }

/****************** roothide specific ****************/
    dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] setIdleTimerDisabled:YES]; //doesn't work with low power mode
    });
	
    exec_set_patch(false);
/****************** roothide specific ****************/


    BOOL removeJailbreakEnabled = [[DOPreferenceManager sharedManager] boolPreferenceValueForKey:@"removeJailbreakEnabled" fallback:NO];
    BOOL tweaksEnabled = [[DOPreferenceManager sharedManager] boolPreferenceValueForKey:@"tweakInjectionEnabled" fallback:YES];
    BOOL idownloadEnabled = [[DOPreferenceManager sharedManager] boolPreferenceValueForKey:@"idownloadEnabled" fallback:NO];
    BOOL appJITEnabled = [[DOPreferenceManager sharedManager] boolPreferenceValueForKey:@"appJITEnabled" fallback:YES];
    NSNumber *jetsamMultiplierOption = [[DOPreferenceManager sharedManager] preferenceValueForKey:@"jetsamMultiplier"];
    
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *startLog = [NSString stringWithFormat:@"Starting Jailbreak (Model: %s, %@, Configuration: {removeJailbreak=%d, tweakInjection=%d, idownload=%d, appJIT=%d})", systemInfo.machine, NSProcessInfo.processInfo.operatingSystemVersionString, removeJailbreakEnabled, tweaksEnabled, idownloadEnabled, appJITEnabled];
    [[DOUIManager sharedInstance] sendLog:startLog debug:YES];
    
    *errOut = [self gatherSystemInformation];
    if (*errOut) return;
    *errOut = [self doExploitation];
    if (*errOut) {
        // We don't care about the return value of cleanup at this point, we just need to prevent a panic on exit
        [self cleanUpExploits];
        return;
    }
    
    gSystemInfo.jailbreakSettings.markAppsAsDebugged = appJITEnabled;
    gSystemInfo.jailbreakSettings.jetsamMultiplier = jetsamMultiplierOption ? (jetsamMultiplierOption.doubleValue / 2) : 0;
    
    
/****************** roothide specific ****************/
    //initialize it before injecting launchdhook
    gSystemInfo.jailbreakInfo.dyld_patch_enabled = [[DOPreferenceManager sharedManager] boolPreferenceValueForKey:@"dyldPatchEnabled" fallback:NO];
/****************** roothide specific ****************/
    
    
    [[DOUIManager sharedInstance] sendLog:DOLocalizedString(@"Building Phys R/W Primitive") debug:NO];
    *errOut = [self buildPhysRWPrimitive];
    if (*errOut) {
        [self cleanUpExploits];
        return;
    }
    [[DOUIManager sharedInstance] sendLog:DOLocalizedString(@"Cleaning Up Exploits") debug:NO];
    *errOut = [self cleanUpExploits];
    if (*errOut) return;
    
    // We will not be able to reset this after elevating privileges, so do it now
    if (removeJailbreakEnabled) [[DOPreferenceManager sharedManager] setPreferenceValue:@NO forKey:@"removeJailbreakEnabled"];

    [[DOUIManager sharedInstance] sendLog:DOLocalizedString(@"Elevating Privileges") debug:NO];
    *errOut = [self elevatePrivileges];

    if (*errOut) return;
    *errOut = [self showNonDefaultSystemApps];
    if (*errOut) {
        [self cleanUpPostExploitation];
        return;
    }
    *errOut = [self ensureDevModeEnabled];
    if (*errOut) {
        [self cleanUpPostExploitation];
        return;
    }

    // Now that we are unsandboxed, populate the jailbreak root path
    *errOut = [[DOEnvironmentManager sharedManager] ensureJailbreakRootExists];
    if (*errOut) {
        [self cleanUpPostExploitation];
        return;
    }
    
    *errOut = [[DOEnvironmentManager sharedManager] prepareBootstrap];
    if (*errOut) return;
    setenv("PATH", "/sbin:/bin:/usr/sbin:/usr/bin:/rootfs/sbin:/rootfs/bin:/rootfs/usr/sbin:/rootfs/usr/bin", 1);
    setenv("TERM", "xterm-256color", 1);

    *errOut = [[DOEnvironmentManager sharedManager] updateBootLogo];
    if (*errOut) {
        [self cleanUpPostExploitation];
        return;
    }
    
    if (!tweaksEnabled) {
        printf("Creating safe mode marker file since tweaks were disabled in settings\n");
        [[NSData data] writeToFile:JBROOT_PATH(@"/basebin/.safe_mode") atomically:YES];
    }
/*************************** roothide specific *******************/
    setBasebinDependency(tweaksEnabled);
/*************************** roothide specific *******************/
    
    [[DOUIManager sharedInstance] sendLog:DOLocalizedString(@"Loading BaseBin TrustCache") debug:NO];
    *errOut = [self loadBasebinTrustcache];
    if (*errOut) {
        [self cleanUpPostExploitation];
        return;
    }

    if (removeJailbreakEnabled) {
        *errOut = [self removeJailbreak];
        [self cleanUpPostExploitation];
        if (!*errOut) *didRemove = YES;
        return;
    }

    [[DOUIManager sharedInstance] sendLog:DOLocalizedString(@"Initializing Environment") debug:NO];
    *errOut = [self injectLaunchdHook];
    if (*errOut) {
        [self cleanUpPostExploitation];
        return;
    }
    
    // After the launchd hook is initialized, we need to make the app believe the device is jailbroken
    [[DOEnvironmentManager sharedManager] setJailbroken:YES withVersion:[NSString stringWithContentsOfFile:JBROOT_PATH(@"/basebin/.version") encoding:NSUTF8StringEncoding error:nil]];
    
/*
    // Now that we can, protect important system files by bind mounting on top of them
    // This will be always be done during the userspace reboot
    // We also do it now though in case there is a failure between the now step and the userspace reboot
    [[DOUIManager sharedInstance] sendLog:DOLocalizedString(@"Initializing Protection") debug:NO];
    *errOut = [self applyProtection];
    if (*errOut) {
        [self cleanUpPostExploitation];
        return;
    }
    
    [[DOUIManager sharedInstance] sendLog:DOLocalizedString(@"Applying Bind Mount") debug:NO];
    *errOut = [self createFakeLib];
    if (*errOut) {
        [self cleanUpPostExploitation];
        return;
    }
*/

/*************************** roothide specific *******************/
[[DOUIManager sharedInstance] sendLog:DOLocalizedString(@"Hiding Jailbreak") debug:NO];

int ret = basebin_generate(false);
if (ret != 0) {
    *errOut = [NSError errorWithDomain:JBErrorDomain code:JBErrorCodeFailedInitFakeLib userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Creating fakelib failed with error: %d", ret]}];
    return;
}

ret = ensure_dyld_trustcache(JBROOT_PATH("/basebin/.fakelib/dyld"));
if (ret != 0) {
    *errOut = [NSError errorWithDomain:JBErrorDomain code:JBErrorCodeFailedInitFakeLib userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Failed to upload dyld trustcache: %d", ret]}];
    return;
}

exec_set_patch(true); /* launchdhook injected and dyld patched, 
now we can enable dyld patching for new process */

// don't use dyld-in-cache due to dyldhooks
setenv("DYLD_IN_CACHE", "0", 1);
setenv("DYLD_SHARED_REGION", "use", 1); //ios18.4+
// don't load tweak during jailbreaking
setenv("DISABLE_TWEAKS", "1", 1);
// using the stock path during jailbreaking
setenv("DYLD_INSERT_LIBRARIES", JBROOT_PATH("/basebin/systemhook.dylib"), 1);

/******************************** roothide specific *************************/

    
    // Unsandbox iconservicesagent so that app icons can work
    exec_cmd_trusted(JBROOT_PATH("/usr/bin/killall"), "-9", "iconservicesagent", NULL);
    
    *errOut = [self finalizeBootstrapIfNeeded];
    if (*errOut) {
        [self cleanUpPostExploitation];
        return;
    }
    
    [[DOEnvironmentManager sharedManager] setIDownloadEnabled:idownloadEnabled needsUnsandbox:NO];
    
/*
    [[DOUIManager sharedInstance] sendLog:DOLocalizedString(@"Checking For Duplicate Apps") debug:NO];
    *errOut = [self ensureNoDuplicateApps];
    if (*errOut) {
        [self cleanUpPostExploitation];
        *showLogs = NO;
        return;
    }
*/

    *errOut = [self cleanUpPostExploitation];


    //printf("Starting launch daemons...\n");
    //exec_cmd_trusted(JBROOT_PATH("/usr/bin/uicache"), "-a", NULL);
    //exec_cmd_trusted(JBROOT_PATH("/usr/bin/launchctl"), "bootstrap", "system", JBROOT_PATH("/Library/LaunchDaemons"), NULL);
    //exec_cmd_trusted(JBROOT_PATH("/usr/bin/launchctl"), "bootstrap", "system", JBROOT_PATH("/basebin/LaunchDaemons"), NULL);
    // Note: This causes the app to freeze in some instances due to launchd only having physrw_pte, we might want to only do it when neccessary
    // It's only neccessary when we don't immediately userspace reboot
    
    printf("Done!\n");
}

- (void)finalize
{
    [[DOUIManager sharedInstance] sendLog:DOLocalizedString(@"Rebooting Userspace") debug:NO];
    [[DOEnvironmentManager sharedManager] rebootUserspace];
}

@end
