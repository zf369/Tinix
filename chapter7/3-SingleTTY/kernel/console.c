// ==========================================
// console.c
// 控制台处理函数函数
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

/* 本文件内函数声明 */
PRIVATE void	set_cursor(unsigned int position);

/*======================================================================*
                            out_char
 *----------------------------------------------------------------------*
 * 作用：输出char到显存中
 *======================================================================*/
PUBLIC void out_char(CONSOLE* p_con, char ch)
{
	// 简化处理，目前将char直接输出到显存，不区分TTY
	t_8 *p_vmem = (t_8 *)(V_MEM_BASE + disp_pos);

	*p_vmem++ = ch;
	*p_vmem++ = DEFAULT_CHAR_COLOR;

	disp_pos += 2;

	set_cursor(disp_pos/2);
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

