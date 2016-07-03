// ==========================================
// tty.c
// 专门处理键盘buffer的进程主函数
// ==========================================

#include "type.h"
#include "const.h"
#include "protect.h"
#include "proto.h"
#include "string.h"
#include "proc.h"
#include "global.h"
#include "keyboard.h"

/*======================================================================*
                            task_tty
 *----------------------------------------------------------------------*
 * 作用：键盘中断处理函数
 *======================================================================*/
PUBLIC void task_tty()
{
	while (1)
	{
		/* forever. yes, forever, there's something which is some kind of forever... */
		keyboard_read();
	}
}

/*======================================================================*
                            in_process
 *----------------------------------------------------------------------*
 * 作用：对键盘缓冲区读取出来的按键进行操作
 *======================================================================*/
PUBLIC void in_process(t_32 key)
{
	char output[2] = {'\0', '\0'};

	// FLAG_EXT 表示不能打印出来的key
	if (!(key & FLAG_EXT))
	{
		output[0] = key & 0xFF;
		disp_str(output);
	}
}

