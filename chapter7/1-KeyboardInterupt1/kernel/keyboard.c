// ==========================================
// keyboard.c
// 键盘中断处理函数
// ==========================================

#include "type.h"
#include "const.h"
#include "protect.h"
#include "proto.h"
#include "string.h"
#include "proc.h"
#include "global.h"
#include "keyboard.h"
#include "keymap.h"

// 键盘缓冲区
PRIVATE KB_INPUT kb_in;

/*======================================================================*
                            keyboard_handler
 *----------------------------------------------------------------------*
 * 作用：键盘中断处理函数
 *======================================================================*/
PUBLIC void keyboard_handler(int irq)
{
	t_8 scan_code = in_byte(KB_DATA);
	
	// 将本次键盘输入存储到缓冲区，如果缓冲区已满，直接丢弃
	if (kb_in.count < KB_IN_BYTES)
	{
		*(kb_in.p_head) = scan_code;

		kb_in.p_head++;
		if (kb_in.p_head == kb_in.buf + KB_IN_BYTES)
		{
			kb_in.p_head = kb_in.buf;
		}

		kb_in.count++;
	}
}

/*======================================================================*
                            init_keyboard
*----------------------------------------------------------------------*
 * 作用：初始化键盘中断处理函数，开启键盘中断
 *======================================================================*/
PUBLIC void init_keyboard()
{
	// 初始化键盘缓冲区结构体
	kb_in.count = 0;
	kb_in.p_head = kb_in.p_tail = kb_in.buf;

	// **************************** 设置 键盘中断 处理函数 ****************************
	put_irq_handler(KEYBOARD_IRQ, keyboard_handler);
	enable_irq(KEYBOARD_IRQ);
}

/*======================================================================*
                            keyboard_read
*----------------------------------------------------------------------*
 * 作用：读取键盘缓冲区的数据进行处理
 *======================================================================*/
PUBLIC void keyboard_read()
{
	t_8 scan_code;
	char output[2];
	t_bool make; /* TRUE : MakeCode   FALSE: BreakCode */

	mem_set(output, 0, 2);

	// 处理键盘缓冲区的操作码
	if (kb_in.count > 0)
	{
		disable_int();

		scan_code = *(kb_in.p_tail);

		kb_in.p_tail++;
		if (kb_in.p_tail == kb_in.buf + KB_IN_BYTES)
		{
			kb_in.p_tail = kb_in.buf;
		}

		kb_in.count--;

		enable_int();

		/* 下面开始解析扫描码 */
		if (scan_code == 0xE1)
		{
			/* 暂时不做任何操作 */
		}
		else if (scan_code == 0xE0)
		{
			/* 暂时不做任何操作 */
		}
		else
		{
			/* 下面处理可打印字符 */

			/* 首先判断Make Code 还是 Break Code */
			make = (scan_code & FLAG_BREAK ? FALSE : TRUE);

			/* 如果是Make Code 就打印，是 Break Code 则不做处理 */
			if (make)
			{
				output[0] = keymap[(scan_code & 0x7F) * MAP_COLS];
				disp_str(output);
			}
		}
	}
}

