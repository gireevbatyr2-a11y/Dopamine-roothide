#import <Foundation/Foundation.h>
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
