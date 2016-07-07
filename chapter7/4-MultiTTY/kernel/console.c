// ==========================================
// console.c
// 控制台处理函数函数
// ==========================================

/*
	回车键:	把光标移到第一列
	换行键:	把光标前进到下一行
*/

#include "type.h"
#include "const.h"
#include "protect.h"
#include "string.h"
#include "proc.h"
#include "tty.h"
#include "console.h"
#include "global.h"
#include "keyboard.h"
#include "proto.h"

/* 本文件内函数声明 */
PRIVATE void	set_cursor(unsigned int position);

/*======================================================================*
                            init_screen
 *----------------------------------------------------------------------*
 * 作用：初始化TTY对应的console
 *======================================================================*/
PUBLIC void init_screen(TTY* p_tty)
{
	// 计算该TTY的index
	int nr_tty = p_tty - tty_table;
	// 根据TTY的index，找到对应console的index
	p_tty->p_console = console_table + nr_tty;

	/************* 初始化CONSOLE结构体 *************/

	// V_MEM_SIZE 0x8000	/* 32K: B8000H -> BFFFFH */
	// 由于2字节对应一个显示字符，所以接下来的显存部分都是以WORD来度量的。
	int v_mem_size = V_MEM_SIZE >> 1; // 显存总大小 (in WORD)

	int con_v_mem_size = v_mem_size / NR_CONSOLES; // 每个控制台占的显存大小 (in WORD)
	p_tty->p_console->original_addr = nr_tty * con_v_mem_size; // 当前控制台占的显存相对于B8000的offset (in WORD)
	p_tty->p_console->v_mem_limit = con_v_mem_size; // 当前控制台占的显存大小 (in WORD)
	p_tty->p_console->current_start_addr = p_tty->p_console->original_addr; // 当前控制台显示到了显存的什么位置 (in WORD)

	p_tty->p_console->cursor = p_tty->p_console->original_addr; // 默认光标位置在最开始处

	if (nr_tty == 0)
	{
		/* 第一个控制台延用目前屏幕的光标位置 */
		p_tty->p_console->cursor = disp_pos / 2;
		disp_pos = 0; // 将原来的disp_pos置为0
	}
	else
	{
		/* 其他控制台先输出"控制台号#" */
		out_char(p_tty->p_console, nr_tty + '0');
		out_char(p_tty->p_console, '#');
	}

	set_cursor(p_tty->p_console->cursor);
}

/*======================================================================*
                            out_char
 *----------------------------------------------------------------------*
 * 作用：输出char到显存中
 *======================================================================*/
PUBLIC void out_char(CONSOLE* p_con, char ch)
{
	// 简化处理，目前将char直接输出到显存，不区分TTY
	t_8 *p_vmem = (t_8 *)(V_MEM_BASE + p_con->cursor * 2);

	*p_vmem++ = ch;
	*p_vmem++ = DEFAULT_CHAR_COLOR;

	p_con->cursor++;

	set_cursor(p_con->cursor);
}

/*======================================================================*
                            is_current_console
 *----------------------------------------------------------------------*
 * 作用：判断该console是否在前台
 *======================================================================*/
PUBLIC t_bool is_current_console(CONSOLE* p_con)
{
	if (p_con == &console_table[nr_current_console])
	{
		return TRUE;
	}

	return FALSE;
}

/*======================================================================*
                            set_cursor
 *----------------------------------------------------------------------*
 * 作用：设置光标位置
 *======================================================================*/
PUBLIC void set_cursor(unsigned int position)
{
	// 移动光标的位置
	disable_int();
	out_byte(CRTC_ADDR_REG, CRTC_DATA_IDX_CURSOR_H);
	out_byte(CRTC_DATA_REG, (position >> 8) & 0xFF);
	out_byte(CRTC_ADDR_REG, CRTC_DATA_IDX_CURSOR_L);
	out_byte(CRTC_DATA_REG, position & 0xFF);
	enable_int();
}

/*======================================================================*
                            set_video_start_addr
 *----------------------------------------------------------------------*
 * 作用：设置显示窗口对应的显存位置
 *======================================================================*/
PRIVATE void set_video_start_addr(t_32 addr)
{
	// 移动窗口的位置
	disable_int();
	out_byte(CRTC_ADDR_REG, CRTC_DATA_IDX_START_ADDR_H);
	out_byte(CRTC_DATA_REG, (addr >> 8) & 0xFF);
	out_byte(CRTC_ADDR_REG, CRTC_DATA_IDX_START_ADDR_L);
	out_byte(CRTC_DATA_REG, addr & 0xFF);
	enable_int();
}

/*======================================================================*
                            select_console
 *----------------------------------------------------------------------*
 * 作用：切换CONSOLE 取值范围 0 ~ (NR_CONSOLES - 1)
 *======================================================================*/
PUBLIC void select_console(int nr_console)	
{
	if ((nr_console < 0) || (nr_console >= NR_CONSOLES))
	{
		return;
	}

	// 切换生效的CONSOLE序号
	nr_current_console = nr_console;

	// 设置光标位置
	set_cursor(console_table[nr_console].cursor);
	// 将窗口切换到该CONSOLE的显存位置
	set_video_start_addr(console_table[nr_console].current_start_addr);
}

/*======================================================================*
                           scroll_screen
 *----------------------------------------------------------------------*
 滚屏.
 *----------------------------------------------------------------------*
 direction:
	SCROLL_SCREEN_UP	: 向上滚屏
	SCROLL_SCREEN_DOWN	: 向下滚屏
	其它			: 不做处理
 *======================================================================*/
PUBLIC void scroll_screen(CONSOLE* p_con, int direction)
{
	if (direction == SCROLL_SCREEN_UP)
	{
		if (p_con->current_start_addr > p_con->original_addr)
		{
			p_con->current_start_addr -= SCREEN_WIDTH;
		}
	}
	else if (direction == SCROLL_SCREEN_DOWN)
	{
		if (p_con->current_start_addr + SCREEN_SIZE < p_con->original_addr + p_con->v_mem_limit)
		{
			p_con->current_start_addr += SCREEN_WIDTH;
		}
	}
	else
	{
		// Nothing to do
	}

	// 设置光标位置
	set_cursor(p_con->cursor);
	// 将窗口切换到该CONSOLE的显存位置
	set_video_start_addr(p_con->current_start_addr);
}
