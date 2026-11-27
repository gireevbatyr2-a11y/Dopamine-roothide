// lara's translation units log with printf/fflush, which is invisible on iOS
// (no stdout). Route printf into the app's file log so stash/recovery failures
// are diagnosable from /var/mobile/Documents/DopamineKernelRW.log.
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdarg.h>

void DOKRWLog(NSString *format, ...);

static void laraLogf(const char *format, ...) __attribute__((format(__printf__, 1, 2)));
static void laraLogf(const char *format, ...)
{
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:@(format) arguments:args];
    va_end(args);
    if (message.length) {
        DOKRWLog(@"[lara] %@", message);
    }
}

#define printf(...) laraLogf(__VA_ARGS__)

#include "darksword.h"
#include "offsets.h"
#include "utils.h"
#include "TaskRop/RemoteCall.h"
#include "TaskRop/RemoteCall.m"
#include "TaskRop/thread.m"
#include "TaskRop/pac.m"
#include "TaskRop/exc.m"
#include "TaskRop/vm.m"
// vm.m defines kernel macro names (VM_PAGE_PACKED_PTR_SHIFT etc.) that collide
// with identically named members of kernelConstant in libjailbreak/info.h,
// which darksword_shim.m includes below; drop them before that include.
#undef VM_PAGE_PACKED_PTR_BITS
#undef VM_PAGE_PACKED_PTR_SHIFT
#undef VM_KERNEL_POINTER_SIGNIFICANT_BITS
#undef PAGE_MASK_K
#include "TaskRop/findcachedataoff.m"
#include "darksword_shim.m"
#include "offsets_shim.m"
#include "utils.m"
#include "persistence.m"
