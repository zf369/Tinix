// ==========================================
// global.h
// 定义和声明全局变量
// ==========================================

/* EXTERN is defined as extern except in global.c */
#ifdef	GLOBAL_VARIABLES_HERE
#undef	EXTERN
#define	EXTERN
#endif

EXTERN int        ticks;

EXTERN int        disp_pos;

EXTERN t_8        gdt_ptr[6];    // gdt pointer: 0~15:Limit  16~47:Base
EXTERN DESCRIPTOR gdt[GDT_SIZE];

EXTERN t_8        idt_ptr[6];    // gdt pointer: 0~15:Limit  16~47:Base
EXTERN GATE       idt[IDT_SIZE];

EXTERN t_32       k_reenter;

EXTERN TSS        tss;

EXTERN PROCESS    *p_proc_ready; // p_proc_ready指向的是接下来要执行的进程结构体

EXTERN int nr_current_console; // 当前生效的tty的index

extern PROCESS    proc_table[];     // 进程表
extern char       task_stack[];     // 所有任务的栈区
extern TASK       task_table[];          // Ring1任务表：Ring1任务的基础数据结构体数组
extern TASK       user_proc_table[];     // Ring3任务表：Ring3用户任务的基础数据结构体数组
extern TTY        tty_table[];      // TTY表：TTY数据结构体数组
extern CONSOLE    console_table[];  // CONSOLE表：CONSOLE结构体数组

extern t_pf_irq_handler irq_table[]; // 中断处理函数指针数组

extern t_sys_call  sys_call_table[]; // 系统调用函数表：当前内核实现的所有系统调用函数

