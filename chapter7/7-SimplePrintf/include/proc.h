// ==========================================
// proc.h
// 进程表相关的结构体和预定义
// ==========================================

typedef struct s_stackframe
{                       /* proc_ptr points here                      	↑ Low	    */
	t_32	gs;         /* ┓                                            │			*/
	t_32	fs;         /* ┃                                            │			*/
	t_32	es;         /* ┃                                            │			*/
	t_32	ds;         /* ┃                                            │			*/
	t_32	edi;		/* ┃                                            │			*/
	t_32	esi;		/* ┣ pushed by save()                           │			*/
	t_32	ebp;		/* ┃                                            │			*/
	t_32	kernel_esp;	/* <- 'popad' will ignore it                    │			*/
	t_32	ebx;		/* ┃                 ↑栈从高地址往低地址增长        ↑           */		
	t_32	edx;		/* ┃                                            │			*/
	t_32	ecx;		/* ┃                                            │			*/
	t_32	eax;		/* ┛                                            │			*/
	t_32	retaddr;	/* return address for assembly code save()      │			*/
	t_32	eip;		/*  ┓                                           │			*/
	t_32	cs;		    /*  ┃                                           │			*/
	t_32	eflags;		/*  ┣ these are pushed by CPU during interrupt	│			*/
	t_32	esp;		/*  ┃						                    │			*/
	t_32	ss;		    /*  ┛					                        ┷High		*/
} STACK_FRAME;

// 进程表的结构体
typedef struct s_proc
{
	STACK_FRAME    regs;    /* process' registers saved in stack frame */

	t_16           ldt_sel; /* selector in gdt giving ldt base and limit*/
	DESCRIPTOR     ldts[LDT_SIZE]; /* local descriptors for code and data */
	                               /* 2 is LDT_SIZE - avoid include protect.h */

	int            ticks;      /* remained ticks */
	int            priority;

	t_32           pid;        /* process id passed in from MM */
	char           p_name[16]; /* name of the process */

	int            nr_tty;     /* tty index of the process */
} PROCESS;

// 每个任务执行所需要的基本数据
typedef struct s_task
{
	t_pf_task initial_eip; // 任务起始的ip
	int stacksize; // 任务的栈大小
	char name[32]; 
} TASK;

/* Number of tasks and processess */
#define NR_TASKS    1
#define NR_PROCS    3

/* stacks of tasks */
#define STACK_SIZE_TTY      0x8000
#define STACK_SIZE_TESTA    0x8000
#define STACK_SIZE_TESTB    0x8000
#define STACK_SIZE_TESTC    0x8000

// 所有进程的栈大小
#define STACK_SIZE_TOTAL    (STACK_SIZE_TTY + \
                             STACK_SIZE_TESTA + \
                             STACK_SIZE_TESTB + \
                             STACK_SIZE_TESTC   \
                            )
