// ==========================================
// global.h
// 定义和声明全局变量
// ==========================================

/* EXTERN is defined as extern except in global.c */
#ifdef	GLOBAL_VARIABLES_HERE
#undef	EXTERN
#define	EXTERN
#endif

EXTERN int        disp_pos;

EXTERN t_8        gdt_ptr[6];    // gdt pointer: 0~15:Limit  16~47:Base
EXTERN DESCRIPTOR gdt[GDT_SIZE];

EXTERN t_8        idt_ptr[6];    // gdt pointer: 0~15:Limit  16~47:Base
EXTERN GATE       idt[IDT_SIZE];

EXTERN t_32       k_reenter;

EXTERN TSS        tss;

EXTERN PROCESS    *p_proc_ready; // p_proc_ready指向的是接下来要执行的进程结构体

extern PROCESS    proc_table[];  // 进程表
extern char       task_stack[];  // 所有任务的栈区
extern TASK       task_table[];  // 任务表：所有任务的基础数据结构体数组

extern t_pf_irq_handler irq_table[]; // 中断处理函数指针数组


