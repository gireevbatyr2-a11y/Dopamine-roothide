#import <Foundation/Foundation.h>
#include <sys/sysctl.h>
#include <mach/mach.h>
#include "offsets.h"
#include <libjailbreak/info.h>

void lara_offsets_init(void) {
    off_proc_p_list_le_next = koffsetof(proc, list_next);
    off_proc_p_pid = koffsetof(proc, pid);
    off_proc_p_proc_ro = koffsetof(proc, proc_ro);
    off_proc_p_name = 0;
    off_task_itk_space = koffsetof(task, itk_space);
    off_task_threads_next = koffsetof(task, threads);
    off_task_task_exc_guard = 0;
    off_ipc_space_is_table = koffsetof(ipc_space, table);
    off_ipc_entry_ie_object = koffsetof(ipc_entry, object);
    off_ipc_port_ip_kobject = koffsetof(ipc_port, kobject);
    off_thread_t_tro = 0;
    off_thread_ro_tro_proc = 0;
    off_thread_ro_tro_task = 0;
    off_thread_machine_upcb = 0;
    off_thread_machine_contextdata = koffsetof(thread, machine_contextData);
    off_thread_ctid = 0;
    off_thread_options = 0;
    off_thread_mutex_lck_mtx_data = 0;
    off_thread_machine_kstackptr = koffsetof(thread, machine_kstackptr);
    off_thread_machine_jop_pid = 0;
    off_thread_machine_rop_pid = 0;
    off_thread_ast = 0;
    off_thread_task_threads_next = 0;
    off_socket_so_usecount = 0;
    off_socket_so_proto = 0;
    off_socket_so_background_thread = 0;
    off_inpcb_inp_list_le_next = 0;
    off_inpcb_inp_pcbinfo = 0;
    off_inpcb_inp_socket = 0;
    off_inpcb_inp_depend6_inp6_icmp6filt = 0;
    off_inpcb_inp_depend6_inp6_chksum = 0;
    sizeof_ipc_entry = 0x10;
}

#pragma mark - offset storage

// Definitions for the offset variables declared in offsets.h. The upstream
// lara offsets.m (xpf/kernelcache driven) is not ported; the subset used by
// the launchd stash is filled in by lara_offsets_init() from gSystemInfo,
// the rest stay 0 and lara's own fallback logic applies.
uint32_t off_inpcb_inp_list_le_next = 0;
uint32_t off_inpcb_inp_pcbinfo = 0;
uint32_t off_inpcb_inp_socket = 0;
uint32_t off_inpcbinfo_ipi_zone = 0;
uint32_t off_inpcb_inp_depend6_inp6_icmp6filt = 0;
uint32_t off_inpcb_inp_depend6_inp6_chksum = 0;
uint32_t off_socket_so_usecount = 0;
uint32_t off_socket_so_proto = 0;
uint32_t off_socket_so_background_thread = 0;
uint32_t off_protosw_pr_input = 0;
uint32_t off_kalloc_type_view_kt_zv_zv_name = 0;
uint32_t off_thread_t_tro = 0;
uint32_t off_thread_ro_tro_proc = 0;
uint32_t off_thread_ro_tro_task = 0;
uint32_t off_thread_machine_upcb = 0;
uint32_t off_thread_machine_contextdata = 0;
uint32_t off_thread_ctid = 0;
uint32_t off_thread_options = 0;
uint32_t off_thread_mutex_lck_mtx_data = 0;
uint32_t off_thread_machine_kstackptr = 0;
uint32_t off_thread_guard_exc_info_code = 0;
uint32_t off_thread_mach_exc_info_code = 0;
uint32_t off_thread_mach_exc_info_os_reason = 0;
uint32_t off_thread_mach_exc_info_exception_type = 0;
uint32_t off_thread_ast = 0;
uint32_t off_thread_task_threads_next = 0;
uint32_t off_thread_machine_jop_pid = 0;
uint32_t off_thread_machine_rop_pid = 0;
uint32_t off_proc_p_list_le_next = 0;
uint32_t off_proc_p_list_le_prev = 0;
uint32_t off_proc_p_proc_ro = 0;
uint32_t off_proc_p_pid = 0;
uint32_t off_proc_p_fd = 0;
uint32_t off_proc_p_flag = 0;
uint32_t off_proc_p_textvp = 0;
uint32_t off_proc_p_name = 0;
uint32_t off_proc_ro_pr_task = 0;
uint32_t off_proc_ro_p_ucred = 0;
uint32_t off_ucred_cr_label = 0;
uint32_t off_task_itk_space = 0;
uint32_t off_task_threads_next = 0;
uint32_t off_task_task_exc_guard = 0;
uint32_t off_task_map = 0;
uint32_t off_filedesc_fd_ofiles = 0;
uint32_t off_filedesc_fd_cdir = 0;
uint32_t off_fileproc_fp_glob = 0;
uint32_t off_fileglob_fg_data = 0;
uint32_t off_fileglob_fg_flag = 0;
uint32_t off_vnode_v_ncchildren_tqh_first = 0;
uint32_t off_vnode_v_nclinks_lh_first = 0;
uint32_t off_vnode_v_parent = 0;
uint32_t off_vnode_v_data = 0;
uint32_t off_vnode_v_name = 0;
uint32_t off_vnode_v_usecount = 0;
uint32_t off_vnode_v_iocount = 0;
uint32_t off_vnode_v_writecount = 0;
uint32_t off_vnode_v_flag = 0;
uint32_t off_vnode_v_mount = 0;
uint32_t off_mount_mnt_flag = 0;
uint32_t off_namecache_nc_vp = 0;
uint32_t off_namecache_nc_child_tqe_next = 0;
uint32_t off_arm_saved_state64_lr = 0;
uint32_t off_arm_saved_state64_pc = 0;
uint32_t off_arm_saved_state_uss_ss_64 = 0;
uint32_t off_ipc_space_is_table = 0;
uint32_t off_ipc_entry_ie_object = 0;
uint32_t off_ipc_port_ip_kobject = 0;
uint32_t off_arm_kernel_saved_state_sp = 0;
uint32_t off_vm_map_hdr = 0;
uint32_t off_vm_map_header_nentries = 0;
uint32_t off_vm_map_entry_links_next = 0;
uint32_t off_vm_map_entry_vme_object_or_delta = 0;
uint32_t off_vm_map_entry_vme_alias = 0;
uint32_t off_vm_map_header_links_next = 0;
uint32_t off_vm_object_vo_un1_vou_size = 0;
uint32_t off_vm_object_ref_count = 0;
uint32_t off_vm_named_entry_backing_copy = 0;
uint32_t off_vm_named_entry_size = 0;
uint32_t off_label_l_perpolicy_amfi = 0;
uint32_t off_label_l_perpolicy_sandbox = 0;
uint32_t sizeof_ipc_entry = 0;
uint64_t smr_base = 0;
uint64_t t1sz_boot = 0;
uint64_t VM_MIN_KERNEL_ADDRESS = 0;
uint64_t VM_MAX_KERNEL_ADDRESS = 0;
uint64_t pac_mask = 0;

cpu_subtype_t get_hw_cpufamily(void) {
    cpu_subtype_t cpuFamily = 0;
    size_t cpuFamilySize = sizeof(cpuFamily);
    sysctlbyname("hw.cpufamily", &cpuFamily, &cpuFamilySize, NULL, 0);
    return cpuFamily;
}

bool is_pac_supported(void) {
    cpu_subtype_t cpusubtype = 0;
    size_t sz = sizeof(cpusubtype);
    if (sysctlbyname("hw.cpusubtype", &cpusubtype, &sz, NULL, 0) != 0) return false;
    return cpusubtype == CPU_SUBTYPE_ARM64E;
}
