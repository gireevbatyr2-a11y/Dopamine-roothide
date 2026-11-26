#import <Foundation/Foundation.h>
#include "darksword.h"
#include <libjailbreak/primitives.h>
#include <libjailbreak/info.h>
#include <libjailbreak/proc.h>
#include "../Exploits/ClearSword/exploit/common.h"

int control_socket = -1;
int rw_socket = -1;
uint64_t kernel_base = 0;
uint64_t kernel_slide = 0;

static void ds_sync_ctx(void) { g_ctx.control_socket = control_socket; g_ctx.rw_socket = rw_socket; }
uint64_t ds_kread64(uint64_t a){ ds_sync_ctx(); return kread64(a); }
uint32_t ds_kread32(uint64_t a){ ds_sync_ctx(); return kread32(a); }
uint16_t ds_kread16(uint64_t a){ ds_sync_ctx(); return kread16(a); }
uint8_t ds_kread8(uint64_t a){ ds_sync_ctx(); return kread8(a); }
void ds_kwrite64(uint64_t a, uint64_t v){ ds_sync_ctx(); kwrite64(a, v); }
void ds_kwrite32(uint64_t a, uint32_t v){ ds_sync_ctx(); kwrite32(a, v); }
void ds_kwrite16(uint64_t a, uint16_t v){ ds_sync_ctx(); kwrite16(a, v); }
void ds_kwrite8(uint64_t a, uint8_t v){ ds_sync_ctx(); kwrite8(a, v); }
void ds_kread(uint64_t a, void *b, uint64_t n){ ds_sync_ctx(); kreadbuf(a, b, n); }
void ds_kwrite(uint64_t a, void *b, uint64_t n){ ds_sync_ctx(); kwritebuf(a, b, n); }
void ds_kreadbuf(uint64_t a, void *b, uint64_t n){ ds_sync_ctx(); kreadbuf(a, b, n); }
void ds_kwritebuf(uint64_t a, const void *b, uint64_t n){ ds_sync_ctx(); kwritebuf(a, b, n); }
uint64_t ds_kreadptr(uint64_t a){ ds_sync_ctx(); return kread_ptr(a); }
uint64_t ds_kreadsmrptr(uint64_t a){ ds_sync_ctx(); return kread_smrptr(a); }
void ds_kwritezoneelement(uint64_t a, const void *b, uint64_t n){ ds_sync_ctx(); kwritebuf(a, b, n); }
uint64_t ds_kallocarrdec(uint64_t p){ return kread_smrptr(p); }
void ds_khexdump(uint64_t a, size_t n){ (void)a; (void)n; }

uint64_t ds_get_kernel_base(void){ return gSystemInfo.kernelConstant.base; }
uint64_t ds_get_kernel_slide(void){ return gSystemInfo.kernelConstant.slide; }
uint64_t ds_get_pcbinfo(void){ return g_ctx.control_socket_pcb; }
uint64_t ds_get_rw_socket_pcb(void){ return g_ctx.rw_socket_pcb; }
uint64_t ds_get_our_proc(void){ return proc_self(); }
uint64_t ds_get_our_task(void){ return proc_task(proc_self()); }
bool ds_isvalid(uint64_t a){ return a > 0xffff000000000000ULL; }
