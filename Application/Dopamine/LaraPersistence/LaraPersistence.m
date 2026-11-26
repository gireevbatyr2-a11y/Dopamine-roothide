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
