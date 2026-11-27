//
//  DOKRWTestReport.m
//  FFKRW
//

#import "DOKRWTestReport.h"
#import "DOJailbreaker.h"
#import "DOEnvironmentManager.h"
#import "DOExploitManager.h"
#import <sys/sysctl.h>
#import <sys/utsname.h>
#import <fcntl.h>
#import <unistd.h>
#import <libjailbreak/machine_info.h>

extern NSString *persist_status_summary(void);

#define DOKRW_REPORT_LOG_TAIL 200

static NSString *DOKRWCPUName(void)
{
    cpu_subtype_t cpuFamily = 0;
    size_t size = sizeof(cpuFamily);
    if (sysctlbyname("hw.cpufamily", &cpuFamily, &size, NULL, 0) != 0) return @"?";

    switch (cpuFamily) {
        case CPUFAMILY_ARM_TYPHOON: return @"A8";
        case CPUFAMILY_ARM_TWISTER: return @"A9";
        case CPUFAMILY_ARM_HURRICANE: return @"A10";
        case CPUFAMILY_ARM_MONSOON_MISTRAL: return @"A11";
        case CPUFAMILY_ARM_VORTEX_TEMPEST: return @"A12";
        case CPUFAMILY_ARM_LIGHTNING_THUNDER: return @"A13";
        case CPUFAMILY_ARM_FIRESTORM_ICESTORM: return @"A14";
        case CPUFAMILY_ARM_BLIZZARD_AVALANCHE: return @"A15";
        case CPUFAMILY_ARM_EVEREST_SAWTOOTH: return @"A16";
        case CPUFAMILY_ARM_COLL: return @"A17";
        default: return [NSString stringWithFormat:@"0x%x", cpuFamily];
    }
}

static NSString *DOKRWSysctlString(const char *name)
{
    char value[256] = {0};
    size_t size = sizeof(value) - 1;
    if (sysctlbyname(name, value, &size, NULL, 0) != 0) return @"?";
    return [NSString stringWithUTF8String:value] ?: @"?";
}

// A TrollStore build carries com.apple.private.security.no-sandbox, so other apps'
// containers are writable. On versions where that entitlement is not honoured the
// app is still sandboxed and privileged file work needs a kernel-side sandbox patch,
// which is a different problem from keeping the primitive alive. The report has to
// say which of the two situations a device is in.
static NSString *DOKRWSandboxProbe(void)
{
    const char *probes[] = {
        "/private/var/mobile/Containers/Data/Application",
        "/private/var/mobile/Containers/Data/System",
    };

    for (size_t i = 0; i < sizeof(probes) / sizeof(probes[0]); i++) {
        NSString *path = [NSString stringWithFormat:@"%s/.ffkrw_probe_%d", probes[i], getpid()];
        int fd = open(path.fileSystemRepresentation, O_RDWR | O_CREAT | O_EXCL | O_CLOEXEC, 0600);
        if (fd < 0) {
            return [NSString stringWithFormat:@"closed(%s)", probes[i]];
        }
        uint8_t byte = 0x31, back = 0;
        bool ok = write(fd, &byte, 1) == 1 && lseek(fd, 0, SEEK_SET) == 0 &&
                  read(fd, &back, 1) == 1 && back == byte;
        close(fd);
        unlink(path.fileSystemRepresentation);
        if (!ok) {
            return [NSString stringWithFormat:@"readonly(%s)", probes[i]];
        }
    }
    return @"open";
}

static NSString *DOKRWLogTail(void)
{
    NSString *path = DOKRWLogPath();
    NSString *contents = path ? [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil] : nil;
    if (!contents) return @"(no log)";

    NSArray<NSString *> *lines = [contents componentsSeparatedByString:@"\n"];
    if (lines.count > DOKRW_REPORT_LOG_TAIL) {
        lines = [lines subarrayWithRange:NSMakeRange(lines.count - DOKRW_REPORT_LOG_TAIL, DOKRW_REPORT_LOG_TAIL)];
    }
    return [lines componentsJoinedByString:@"\n"];
}

NSString *DOKRWTestReport(void)
{
    DOEnvironmentManager *env = [DOEnvironmentManager sharedManager];
    DOExploitManager *exploits = [DOExploitManager sharedManager];
    DOJailbreaker *kernelRW = [DOJailbreaker sharedInstance];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    struct utsname info = {0};
    uname(&info);

    DOExploit *kernelExploit = exploits.selectedKernelExploit;
    NSString *usedExploit = [defaults stringForKey:@"DOKRWLastKernelExploitName"];
    NSNumber *usedPersistent = [defaults objectForKey:@"DOKRWLastKernelExploitResumable"];

    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    [lines addObject:@"FFKRW-REPORT v1"];
    [lines addObject:[NSString stringWithFormat:@"fork_sha=%@",
                      [[NSBundle mainBundle] objectForInfoDictionaryKey:@"DOKRWForkSHA"] ?: @"unknown"]];
    [lines addObject:[NSString stringWithFormat:@"app=%@ (%@)",
                      [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"?",
                      [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"?"]];
    [lines addObject:[NSString stringWithFormat:@"device=%@", [NSString stringWithUTF8String:info.machine] ?: @"?"]];
    [lines addObject:[NSString stringWithFormat:@"cpu=%@", DOKRWCPUName()]];
    [lines addObject:[NSString stringWithFormat:@"arm64e=%d", env.isArm64e]];
    [lines addObject:[NSString stringWithFormat:@"ios=%@", env.systemVersion ?: DOKRWSysctlString("kern.osproductversion")]];
    [lines addObject:[NSString stringWithFormat:@"build=%@", DOKRWSysctlString("kern.osversion")]];
    [lines addObject:[NSString stringWithFormat:@"support_string=%@", env.versionSupportString ?: @"?"]];
    [lines addObject:[NSString stringWithFormat:@"app_supported=%d", env.isSupported]];
    [lines addObject:[NSString stringWithFormat:@"exploit_selected=%@", kernelExploit.displayName ?: @"none"]];
    [lines addObject:[NSString stringWithFormat:@"exploit_used=%@", usedExploit ?: @"none"]];
    [lines addObject:[NSString stringWithFormat:@"exploit_resumable=%@", usedPersistent ? usedPersistent.stringValue : @"?"]];
    [lines addObject:[NSString stringWithFormat:@"pac_bypass_required=%d", env.isPACBypassRequired]];
    [lines addObject:[NSString stringWithFormat:@"ppl_bypass_required=%d", env.isPPLBypassRequired]];
    [lines addObject:[NSString stringWithFormat:@"sptm=%d", env.isSPTM]];
    [lines addObject:[NSString stringWithFormat:@"kernel_rw_ready=%d", kernelRW.kernelRWReady]];
    [lines addObject:[NSString stringWithFormat:@"kcall=%d", kernelRW.isKcallAvailable]];
    [lines addObject:[NSString stringWithFormat:@"base=0x%llx", (unsigned long long)kernelRW.kernelBase]];
    [lines addObject:[NSString stringWithFormat:@"slide=0x%llx", (unsigned long long)kernelRW.kernelSlide]];
    [lines addObject:[NSString stringWithFormat:@"extmod_offset=0x%x", kernelRW.extmodOffset]];
    [lines addObject:[NSString stringWithFormat:@"boot_session=%@", [defaults stringForKey:@"DOKRWBootSessionUUID"] ?: @"?"]];
    [lines addObject:[NSString stringWithFormat:@"exploit_ran_this_boot=%d", kernelRW.exploitRanThisBoot]];
    [lines addObject:[NSString stringWithFormat:@"sandbox=%@", DOKRWSandboxProbe()]];
    [lines addObject:[NSString stringWithFormat:@"persist=%@", persist_status_summary() ?: @"unavailable"]];
    [lines addObject:@"--- log ---"];
    [lines addObject:DOKRWLogTail()];

    return [lines componentsJoinedByString:@"\n"];
}

NSURL *DOKRWTestReportSave(void)
{
    NSString *report = DOKRWTestReport();
    NSURL *documents = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
    if (!documents) return nil;

    NSURL *url = [documents URLByAppendingPathComponent:@"FFKRW-report.txt"];
    NSError *error = nil;
    if (![report writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        DOKRWLog(@"report: write failed: %@", error.localizedDescription);
        return nil;
    }
    return url;
}
