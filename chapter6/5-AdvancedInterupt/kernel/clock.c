// ==========================================
// clock.c
// 时钟中断处理函数，进程调度算法在此
// ==========================================

#include "type.h"
#include "const.h"
#include "protect.h"
#include "proto.h"
#include "proc.h"
#include "global.h"

/*======================================================================*
                            clock_handler
 *----------------------------------------------------------------------*
 * 作用：时钟中断处理函数，进程调度处理
 *======================================================================*/
PUBLIC void clock_handler(int irq)
{
	disp_str("#");

	if (k_reenter != 0) 
	{
		disp_str("!");
		return;
	}
	
	// 进程调度算法1: 进程表中的进程顺序执行，均分时间片
	p_proc_ready++;

	if (p_proc_ready >= proc_table + NR_TASKS)
	{
		// 如果已经是最后一个进程了，则跳到第一个进程执行
		p_proc_ready = proc_table;
	}
}