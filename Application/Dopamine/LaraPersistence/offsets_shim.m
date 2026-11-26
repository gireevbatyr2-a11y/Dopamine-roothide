#import <Foundation/Foundation.h>
#include "offsets.h"
#include <libjailbreak/info.h>
#include <libjailbreak/info.h>

void lara_offsets_init(void) {
    off_proc_p_list_le_next = koffsetof(proc, p_list_le_next);
    off_proc_p_pid = koffsetof(proc, p_pid);
    off_proc_p_proc_ro = koffsetof(proc, p_proc_ro);
    off_proc_p_name = koffsetof(proc, p_name);
    off_task_itk_space = koffsetof(task, itk_space);
    off_task_threads_next = koffsetof(task, threads_next);
    off_ipc_space_is_table = koffsetof(ipc_space, is_table);
    off_ipc_entry_ie_object = koffsetof(ipc_entry, ie_object);
    off_ipc_port_ip_kobject = koffsetof(ipc_port, ip_kobject);
    off_thread_t_tro = koffsetof(thread, t_tro);
    off_thread_ro_tro_proc = koffsetof(thread_ro, tro_proc);
    off_thread_ro_tro_task = koffsetof(thread_ro, tro_task);
    off_thread_machine_upcb = koffsetof(thread, machine_upcb);
    off_thread_machine_contextdata = koffsetof(thread, machine_contextdata);
    off_thread_ctid = koffsetof(thread, ctid);
    off_thread_options = koffsetof(thread, options);
    off_thread_mutex_lck_mtx_data = koffsetof(thread, mutex_lck_mtx_data);
    off_thread_machine_kstackptr = koffsetof(thread, machine_kstackptr);
    off_thread_machine_jop_pid = koffsetof(thread, machine_jop_pid);
    off_thread_machine_rop_pid = koffsetof(thread, machine_rop_pid);
    off_thread_ast = koffsetof(thread, ast);
    off_thread_task_threads_next = koffsetof(thread, task_threads_next);
    off_socket_so_usecount = koffsetof(socket, so_usecount);
    off_socket_so_proto = koffsetof(socket, so_proto);
    off_socket_so_background_thread = koffsetof(socket, so_background_thread);
    off_inpcb_inp_list_le_next = koffsetof(inpcb, inp_list_le_next);
    off_inpcb_inp_pcbinfo = koffsetof(inpcb, inp_pcbinfo);
    off_inpcb_inp_socket = koffsetof(inpcb, inp_socket);
    off_inpcb_inp_depend6_inp6_icmp6filt = koffsetof(inpcb, inp_depend6_inp6_icmp6filt);
    off_inpcb_inp_depend6_inp6_chksum = koffsetof(inpcb, inp_depend6_inp6_chksum);
}
