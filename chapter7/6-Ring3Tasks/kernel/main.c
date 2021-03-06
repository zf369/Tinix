// ==========================================
// main.c
// 进程相关的函数
// ==========================================

#include "type.h"
#include "const.h"
#include "protect.h"
#include "string.h"
#include "proc.h"
#include "tty.h"
#include "console.h"
#include "global.h"
#include "proto.h"

/*======================================================================*
                            tinix_main
*----------------------------------------------------------------------*
 * 作用：初始化进程表，然后调用汇编的restart函数
 *======================================================================*/
PUBLIC void tinix_main()
{
	disp_str("-----\"tinix_main\" begins-----\n");

	// **************************** 初始化进程表 ****************************
	TASK *p_task;
	PROCESS *p_proc = proc_table;
	char *p_task_stack = task_stack + STACK_SIZE_TOTAL;
	t_16 selector_ldt = SELECTOR_LDT_FIRST;

	int i;
	t_8		privilege;
	t_8		rpl;
	int		eflags;

	for (i = 0; i < NR_TASKS + NR_PROCS; i++)
	{
		if (i < NR_TASKS)
		{
			/* Ring1任务 */

			p_task = task_table + i;
			privilege = PRIVILEGE_TASK;
			rpl = RPL_TASK;

			// 设置进程的eflags,
			// IF=1 IF(bit 9) [Interrupt enable flag] 
			// 该标志用于控制处理器对可屏蔽中断请求(maskable interrupt requests)的响应。置1响应可屏蔽中断，反之则禁止可屏蔽中断。
			// IOPL=1, IOPL(bits 12 and 13) [I/O privilege level field] 
			// 指示当前运行任务的I/O特权级(I/O privilege level)，
			// 正在运行任务的当前特权级(CPL)必须小于或等于I/O特权级才能允许访问I/O地址空间。
			// 这个域只能在CPL为0时才能通过POPF以及IRET指令修改。
			eflags = 0x1202;	/* IF=1, IOPL=1, bit 2 is always 1 */
		}
		else
		{
			/* Ring3用户进程 */

			p_task = user_proc_table + (i - NR_TASKS);
			privilege	= PRIVILEGE_USER;
			rpl = RPL_USER;

			eflags = 0x202;	/* IF=1, bit 2 is always 1 */
		}

		str_cpy(p_proc->p_name, p_task->name);  // Set process name
		p_proc->pid = i;  // Set process id

		// 设置进程表中的ldt_set，设置为GDT中LDT的selector
		p_proc->ldt_sel = selector_ldt;

		// 将GDT中代码段的描述符复制到进程表的LDT[0]中
		mem_cpy(&p_proc->ldts[0], &gdt[SELECTOR_KERNEL_CS >> 3], sizeof(DESCRIPTOR));
		// 将LDT[0]中的DPL修改成 privilege(ring 1) 
		p_proc->ldts[0].attr1 = DA_C | privilege << 5;	

		// 将GDT中数据段的描述符复制到进程表的LDT[1]中
		mem_cpy(&p_proc->ldts[1], &gdt[SELECTOR_KERNEL_DS >> 3], sizeof(DESCRIPTOR));
		// 将LDT[1]中的DPL修改成 privilege(ring 1) 
		p_proc->ldts[1].attr1 = DA_DRW | privilege << 5;

		// 设置进程表中代码段CS的选择子 cs selector = 0 | SA_TIL | RPL_TASK
		p_proc->regs.cs		= ((8 * 0) & SA_RPL_MASK & SA_TI_MASK) | SA_TIL | rpl;

		// 设置进程表中数据段DS、ES、FS、SS的选择子 selector = 8 | SA_TIL | RPL_TASK
		p_proc->regs.ds		= ((8 * 1) & SA_RPL_MASK & SA_TI_MASK) | SA_TIL | rpl;
		p_proc->regs.es		= ((8 * 1) & SA_RPL_MASK & SA_TI_MASK) | SA_TIL | rpl;
		p_proc->regs.fs		= ((8 * 1) & SA_RPL_MASK & SA_TI_MASK) | SA_TIL | rpl;
		p_proc->regs.ss		= ((8 * 1) & SA_RPL_MASK & SA_TI_MASK) | SA_TIL | rpl;

		// 设置进程表中GS的选择子 selector = SELECTOR_KERNEL_GS | RPL_TASK
		p_proc->regs.gs		= (SELECTOR_KERNEL_GS & SA_RPL_MASK) | rpl;

		// 设置进程表中的起始eip，从任务表中读取
		p_proc->regs.eip	= (t_32)p_task->initial_eip;

		// 设置进程的栈区为全局变量task_stack处，char task_stack[STACK_SIZE_TOTAL]; 
		p_proc->regs.esp	= (t_32)p_task_stack;

		// 最后，设置进程的eflags,
		// IF=1 IF(bit 9) [Interrupt enable flag] 
		// 该标志用于控制处理器对可屏蔽中断请求(maskable interrupt requests)的响应。置1响应可屏蔽中断，反之则禁止可屏蔽中断。
		// IOPL=1, IOPL(bits 12 and 13) [I/O privilege level field] 
		// 指示当前运行任务的I/O特权级(I/O privilege level)，
		// 正在运行任务的当前特权级(CPL)必须小于或等于I/O特权级才能允许访问I/O地址空间。
		// 这个域只能在CPL为0时才能通过POPF以及IRET指令修改。
		p_proc->regs.eflags	= eflags;	// IF=1, IOPL=1, bit 2 is always 1.


		// ****** 移动任务表、进程表、栈、LDT *********
		p_task_stack -= p_task->stacksize;
		p_proc++;
		p_task++;
		selector_ldt += (1 << 3);  // 进程对应的LDT描述符向后移动8字节
	}

	// 设置进程的优先级
	proc_table[0].ticks = proc_table[0].priority = 15;
	proc_table[1].ticks = proc_table[1].priority = 5;
	proc_table[2].ticks = proc_table[2].priority = 5;
	proc_table[3].ticks = proc_table[3].priority = 5;

	// **************************** 初始化时钟中断重入标志位 ****************************
	k_reenter = 0;

	// **************************** 初始化时钟计数器ticks ****************************
	ticks = 0;

	// **************************** 设置 p_proc_ready ****************************
	p_proc_ready = proc_table;

	// **************************** 初始化 时钟中断 处理函数 ****************************
	init_clock();

	// **************************** 调用汇编中的restart函数 ****************************
	restart();

	// jmp $
	while (1)
	{

	}
}

/*======================================================================*
                            TestA
*----------------------------------------------------------------------*
 * 作用：进程A的主函数
 *======================================================================*/
PUBLIC void TestA()
{
	while (1)
	{
		milli_delay(10);
	}
}

/*======================================================================*
                            TestB
*----------------------------------------------------------------------*
 * 作用：进程B的主函数
 *======================================================================*/
PUBLIC void TestB()
{
	while (1)
	{
		milli_delay(10);
	}
}

/*======================================================================*
                            TestC
*----------------------------------------------------------------------*
 * 作用：进程C的主函数
 *======================================================================*/
PUBLIC void TestC()
{
	while (1)
	{
		milli_delay(10);
	}
}