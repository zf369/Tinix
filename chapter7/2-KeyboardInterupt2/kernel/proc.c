// ==========================================
// proc.c
// 内核函数，用于实现系统调用功能
// ==========================================

#include "type.h"
#include "const.h"
#include "protect.h"
#include "proto.h"
#include "string.h"
#include "proc.h"
#include "global.h"

/*======================================================================*
                            schedule
 *----------------------------------------------------------------------*
 * 作用：进行进程调度
 *======================================================================*/
PUBLIC void schedule()
{
	PROCESS *p;
	int greatest_ticks = 0;

	while (greatest_ticks <= 0)
	{
		// 进程调度算法: 从进程表中选取剩余tick数最大的进程执行
		for (p = proc_table; p < proc_table + NR_TASKS; p++)
		{
			if (p->ticks > greatest_ticks)
			{
				greatest_ticks = p->ticks;
				p_proc_ready = p;
			}
		}

		// 如果所有进程的ticks均为0了，那么重置所有进程的ticks，然后重新调度进程
		if (greatest_ticks <= 0)
		{
			for (p = proc_table; p < proc_table + NR_TASKS; p++)
			{
				p->ticks = p->priority;
			}
		}
	}

	if (p_proc_ready >= proc_table + NR_TASKS)
	{
		// 如果已经是最后一个进程了，则跳到第一个进程执行
		p_proc_ready = proc_table;
	}
}


/*======================================================================*
                            sys_get_ticks
 *----------------------------------------------------------------------*
 * 作用：最简单的系统调用函数，返回了内核中的全局变量ticks
 *======================================================================*/
PUBLIC int sys_get_ticks()
{
	return ticks;
}







