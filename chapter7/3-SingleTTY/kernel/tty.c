// ==========================================
// tty.c
// 专门处理键盘buffer的进程主函数
// ==========================================

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

#define TTY_FIRST (tty_table)
#define TTY_END   (tty_table + NR_CONSOLES)

/* 本文件内函数声明 */
PRIVATE void init_tty(TTY* p_tty);
PRIVATE void tty_do_read(TTY* p_tty);
PRIVATE void tty_do_write(TTY* p_tty);

/*======================================================================*
                            task_tty
 *----------------------------------------------------------------------*
 * 作用：键盘中断处理函数
 *======================================================================*/
PUBLIC void task_tty()
{
	TTY *p_tty;

	// 初始化键盘中断放到这里，进程开始执行的时候执行一次
	init_keyboard();

	// 遍历初始化所有TTY
	for (p_tty = TTY_FIRST; p_tty < TTY_END; p_tty++)
	{
		init_tty(p_tty);
	}

	nr_current_console = 0;    // 最开始生效的是第一个TTY

	while (1)
	{
		// 轮询所有TTY，如果当前TTY在前台，读取键盘缓冲区，显示到显存中
		for (p_tty = TTY_FIRST; p_tty < TTY_END; p_tty++)
		{
			tty_do_read(p_tty);
			tty_do_write(p_tty);
		}
	}
}

/*======================================================================*
                            init_tty
 *----------------------------------------------------------------------*
 * 作用：初始化TTY
 *======================================================================*/
PRIVATE void init_tty(TTY* p_tty)
{
	p_tty->inbuf_count = 0;
	p_tty->p_inbuf_head = p_tty->p_inbuf_tail = p_tty->in_buf;

	// 计算该TTY的index
	int nr_tty = p_tty - tty_table;
	// 根据TTY的index，找到对应console的index
	p_tty->p_console = console_table + nr_tty;
}

/*======================================================================*
                            in_process
 *----------------------------------------------------------------------*
 * 作用：对键盘缓冲区读取出来的按键进行操作
 *======================================================================*/
PUBLIC void in_process(TTY *p_tty, t_32 key)
{
	// FLAG_EXT 表示不能打印出来的key
	if (!(key & FLAG_EXT))
	{
		// 将本次键盘输入存储到对应TTY的缓冲区，如果缓冲区已满，直接丢弃
		if (p_tty->inbuf_count < TTY_IN_BYTES)
		{
			*(p_tty->p_inbuf_head) = key;

			p_tty->p_inbuf_head++;
			if (p_tty->p_inbuf_head == p_tty->in_buf + TTY_IN_BYTES)
			{
				p_tty->p_inbuf_head = p_tty->in_buf;
			}

			p_tty->inbuf_count++;
		}
	}
	else
	{
		int raw_code = key & MASK_RAW;
		switch (raw_code)
		{
		case UP:
			if ((key & FLAG_SHIFT_L) || (key & FLAG_SHIFT_R)) 
			{	
				/* Shift + Up */

				// 设置屏幕开始的行数为15行
				disable_int();
				out_byte(CRTC_ADDR_REG, CRTC_DATA_IDX_START_ADDR_H);
				out_byte(CRTC_DATA_REG, ((80*15) >> 8) & 0xFF);
				out_byte(CRTC_ADDR_REG, CRTC_DATA_IDX_START_ADDR_L);
				out_byte(CRTC_DATA_REG, (80*15) & 0xFF);
				enable_int();
			}
			break;

		case DOWN:
			if ((key & FLAG_SHIFT_L) || (key & FLAG_SHIFT_R)) 
			{	
				/* Shift + Down */
			}
			break;

		default:
			break;
		}
	}
}

/*======================================================================*
                            tty_do_read
 *----------------------------------------------------------------------*
 * 作用：读取键盘缓冲区
 *======================================================================*/
PRIVATE void tty_do_read(TTY* p_tty)
{
	if (is_current_console(p_tty->p_console))
	{
		keyboard_read(p_tty);
	}
}

/*======================================================================*
                            tty_do_write
 *----------------------------------------------------------------------*
 * 作用：调用out_char将TTY对应缓冲区中的字符输出
 *======================================================================*/
PRIVATE void tty_do_write(TTY* p_tty)
{
	if (p_tty->inbuf_count > 0)
	{
		char ch = *(p_tty->p_inbuf_tail);

		p_tty->p_inbuf_tail++;
		if (p_tty->p_inbuf_tail == p_tty->in_buf + TTY_IN_BYTES)
		{
			p_tty->p_inbuf_tail = p_tty->in_buf;
		}

		p_tty->inbuf_count--;

		out_char(p_tty->p_console, ch);
	}
}