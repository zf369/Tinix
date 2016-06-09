// ==========================================
// main.c
// 进程相关的函数
// ==========================================

#include "type.h"
#include "const.h"
#include "protect.h"
#include "proto.h"
#include "string.h"
#include "proc.h"
#include "global.h"

/*======================================================================*
                            tinix_main
*----------------------------------------------------------------------*
 * 作用：初始化进程表，然后调用汇编的restart函数
 *======================================================================*/
PUBLIC void tinix_main()
{
	disp_str("-----\"tinix_main\" begins-----\n");

	// **************************** 初始化进程表 ****************************
	PROCESS *p_proc = proc_table;
	
	// 设置进程表中的ldt_set，设置为GDT中LDT的selector
	p_proc->ldt_sel = SELECTOR_LDT_FIRST;

	// 将GDT中代码段的描述符复制到进程表的LDT[0]中
	mem_cpy(&p_proc->ldts[0], &gdt[SELECTOR_KERNEL_CS >> 3], sizeof(DESCRIPTOR));
	// 将LDT[0]中的DPL修改成 PRIVILEGE_TASK(ring 1) 
	p_proc->ldts[0].attr1 = DA_C | PRIVILEGE_TASK << 5;	

	// 将GDT中数据段的描述符复制到进程表的LDT[1]中
	mem_cpy(&p_proc->ldts[1], &gdt[SELECTOR_KERNEL_DS >> 3], sizeof(DESCRIPTOR));
	// 将LDT[1]中的DPL修改成 PRIVILEGE_TASK(ring 1) 
	p_proc->ldts[1].attr1 = DA_DRW | PRIVILEGE_TASK << 5;

	// 设置进程表中代码段CS的选择子 cs selector = 0 | SA_TIL | RPL_TASK
	p_proc->regs.cs		= ((8 * 0) & SA_RPL_MASK & SA_TI_MASK) | SA_TIL | RPL_TASK;

	// 设置进程表中数据段DS、ES、FS、SS的选择子 selector = 8 | SA_TIL | RPL_TASK
	p_proc->regs.ds		= ((8 * 1) & SA_RPL_MASK & SA_TI_MASK) | SA_TIL | RPL_TASK;
	p_proc->regs.es		= ((8 * 1) & SA_RPL_MASK & SA_TI_MASK) | SA_TIL | RPL_TASK;
	p_proc->regs.fs		= ((8 * 1) & SA_RPL_MASK & SA_TI_MASK) | SA_TIL | RPL_TASK;
	p_proc->regs.ss		= ((8 * 1) & SA_RPL_MASK & SA_TI_MASK) | SA_TIL | RPL_TASK;

	// 设置进程表中GS的选择子 selector = SELECTOR_KERNEL_GS | RPL_TASK
	p_proc->regs.gs		= (SELECTOR_KERNEL_GS & SA_RPL_MASK) | RPL_TASK;

	// 设置进程表中的起始eip=TestA，即从TestA函数开始执行
	p_proc->regs.eip	= (t_32)TestA;

	// 设置进程的栈区为全局变量task_stack处，char task_stack[STACK_SIZE_TOTAL]; 
	p_proc->regs.esp	= (t_32)task_stack + STACK_SIZE_TOTAL;

	// 最后，设置进程的eflags,
	// IF=1 IF(bit 9) [Interrupt enable flag] 
	// 该标志用于控制处理器对可屏蔽中断请求(maskable interrupt requests)的响应。置1响应可屏蔽中断，反之则禁止可屏蔽中断。
	// IOPL=1, IOPL(bits 12 and 13) [I/O privilege level field] 
	// 指示当前运行任务的I/O特权级(I/O privilege level)，
	// 正在运行任务的当前特权级(CPL)必须小于或等于I/O特权级才能允许访问I/O地址空间。
	// 这个域只能在CPL为0时才能通过POPF以及IRET指令修改。
	p_proc->regs.eflags	= 0x1202;	// IF=1, IOPL=1, bit 2 is always 1.
	
	// **************************** 设置 p_proc_ready ****************************
	p_proc_ready = proc_table;


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
	int i = 0;

	while (1)
	{
		disp_str("A");
		disp_int(i++);
		disp_str(".");

		delay(1);
	}
}

