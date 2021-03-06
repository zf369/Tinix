// ==========================================
// keyboard.c
// 键盘中断处理函数
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
#include "keymap.h"
#include "proto.h"

// 键盘缓冲区
PRIVATE KB_INPUT kb_in;

PRIVATE t_bool code_with_E0;
PRIVATE t_bool shift_l;    /* l shift state	*/
PRIVATE t_bool shift_r;    /* r shift state	*/
PRIVATE t_bool alt_l;      /* l alt state   */
PRIVATE t_bool alt_r;      /* r left state  */
PRIVATE t_bool ctrl_l;     /* l ctrl state  */
PRIVATE t_bool ctrl_r;     /* l ctrl state  */
PRIVATE t_bool caps_lock;  /* Caps Lock     */
PRIVATE t_bool num_lock;   /* Num Lock      */
PRIVATE t_bool scroll_lock;/* Scroll Lock   */

PRIVATE int column = 0;    /* keyrow[column] 将是 keymap 中某一个值 */

/* 本文件内函数声明 */
PRIVATE t_8 get_byte_from_kb_buf();
PRIVATE void	set_leds();
PRIVATE void	kb_wait();
PRIVATE void	kb_ack();

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
	code_with_E0 = FALSE;
	shift_l	= FALSE;
	shift_r	= FALSE;
	ctrl_l	= FALSE;
	ctrl_r	= FALSE;
	alt_l	= FALSE;
	alt_l	= FALSE;
	caps_lock	= FALSE;
	num_lock	= TRUE;
	scroll_lock	= FALSE;
	
	// 初始化键盘缓冲区结构体
	kb_in.count = 0;
	kb_in.p_head = kb_in.p_tail = kb_in.buf;

	set_leds();

	// **************************** 设置 键盘中断 处理函数 ****************************
	put_irq_handler(KEYBOARD_IRQ, keyboard_handler);
	enable_irq(KEYBOARD_IRQ);
}

/*======================================================================*
                            keyboard_read
*----------------------------------------------------------------------*
 * 作用：读取键盘缓冲区的数据进行处理
 *======================================================================*/
PUBLIC void keyboard_read(TTY *p_tty)
{
	t_8 scan_code;
	t_bool make; /* TRUE : MakeCode   FALSE: BreakCode */

	t_32 key = 0; /* 用一个整型来表示一个键。 */
	              /* 比如，如果 Home 被按下，则 key 值将为定义在 keyboard.h 中的 'HOME'。*/
	t_32 *keyrow; /* 指向 keymap[] 的某一行 */

	// 处理键盘缓冲区的操作码
	if (kb_in.count > 0)
	{
		code_with_E0 = FALSE;

		scan_code = get_byte_from_kb_buf();

		/* 下面开始解析扫描码 */
		if (scan_code == 0xE1)
		{
			int i;
			t_8 pausebreak_scan_code[] = {0xE1, 0x1D, 0x45, 0xE1, 0x9D, 0xC5};
			t_bool is_pausebreak = TRUE;
			for(i=1;i<6;i++)
			{
				if (get_byte_from_kb_buf() != pausebreak_scan_code[i]) 
				{
					is_pausebreak = FALSE;
					break;
				}
			}
			if (is_pausebreak) 
			{
				key = PAUSEBREAK;
			}
		}
		else if (scan_code == 0xE0)
		{
			code_with_E0 = TRUE;
			scan_code = get_byte_from_kb_buf();

			/* PrintScreen 被按下 */
			if (scan_code == 0x2A) 
			{
				code_with_E0 = FALSE;
				if ((scan_code = get_byte_from_kb_buf()) == 0xE0) 
				{
					code_with_E0 = TRUE;
					if ((scan_code = get_byte_from_kb_buf()) == 0x37) 
					{
						key = PRINTSCREEN;
						make = TRUE;
					}
				}
			}

			/* PrintScreen 被释放 */
			if (scan_code == 0xB7) 
			{
				code_with_E0 = FALSE;
				if ((scan_code = get_byte_from_kb_buf()) == 0xE0) 
				{
					code_with_E0 = TRUE;
					if ((scan_code = get_byte_from_kb_buf()) == 0xAA) 
					{
						key = PRINTSCREEN;
						make = FALSE;
					}
				}
			}
		} 
		/* 如果不是 PrintScreen。则此时 scan_code 为 0xE0 紧跟的那个值。 */

		if ((key != PAUSEBREAK) && (key != PRINTSCREEN))
		{
			/* 首先判断Make Code 还是 Break Code */
			make = (scan_code & FLAG_BREAK ? FALSE : TRUE);

			/* 先定位到 keymap 中的行 */
			keyrow = &keymap[(scan_code & 0x7F) * MAP_COLS];

			column = 0;
			
			t_bool caps = shift_l || shift_r;
			if (caps_lock) 
			{
				if ((keyrow[0] >= 'a') && (keyrow[0] <= 'z'))
				{
					caps = !caps;
				}
			}
			if (caps) 
			{
				column = 1;
			}

			if (code_with_E0)
			{
				column = 2;
			}

			key = keyrow[column];

			switch (key)
			{
			case SHIFT_L:
				shift_l	= make;
				break;
			case SHIFT_R:
				shift_r	= make;
				break;
			case CTRL_L:
				ctrl_l	= make;
				break;
			case CTRL_R:
				ctrl_r	= make;
				break;
			case ALT_L:
				alt_l	= make;
				break;
			case ALT_R:
				alt_l	= make;
				break;
			case CAPS_LOCK:
				if (make) 
				{
					caps_lock   = !caps_lock;
					set_leds();
				}
				break;
			case NUM_LOCK:
				if (make) 
				{
					num_lock    = !num_lock;
					set_leds();
				}
				break;
			case SCROLL_LOCK:
				if (make) 
				{
					scroll_lock = !scroll_lock;
					set_leds();
				}
				break;
			default:
				break;
			}
		}

		if (make)
		{
			t_bool pad = FALSE;

			/* 首先处理小键盘 */
			if ((key >= PAD_SLASH) && (key <= PAD_9))
			{
				pad = TRUE;
				switch (key)
				{
				/* '/', '*', '-', '+', and 'Enter' in num pad  */
				case PAD_SLASH:
					key = '/';
					break;

				case PAD_STAR:
					key = '*';
					break;

				case PAD_MINUS:
					key = '-';
					break;

				case PAD_PLUS:
					key = '+';
					break;

				case PAD_ENTER:
					key = ENTER;
					break;

				default:
					/* keys whose value depends on the NumLock */
					if (num_lock)
					{
						if ((key >= PAD_0) && (key <= PAD_9))
						{
							key = key - PAD_0 + '0';
						}
						else if (key == PAD_DOT)
						{
							key = '.';
						}
					}
					else
					{
						switch (key)
						{
						case PAD_HOME:
							key = HOME;
							break;

						case PAD_END:
							key = END;
							break;

						case PAD_PAGEUP:
							key = PAGEUP;
							break;

						case PAD_PAGEDOWN:
							key = PAGEDOWN;
							break;

						case PAD_INS:
							key = INSERT;
							break;

						case PAD_UP:
							key = UP;
							break;

						case PAD_DOWN:
							key = DOWN;
							break;

						case PAD_LEFT:
							key = LEFT;
							break;

						case PAD_RIGHT:
							key = RIGHT;
							break;

						case PAD_DOT:
							key = DELETE;
							break;

						default:
							break;
						}
					}

					break;
				}
			}

			key |= shift_l  ? FLAG_SHIFT_L	: 0;
			key |= shift_r  ? FLAG_SHIFT_R	: 0;
			key |= ctrl_l   ? FLAG_CTRL_L	: 0;
			key |= ctrl_r   ? FLAG_CTRL_R	: 0;
			key |= alt_l    ? FLAG_ALT_L	: 0;
			key |= alt_r    ? FLAG_ALT_R	: 0;

			key |= pad      ? FLAG_PAD      : 0;

			in_process(p_tty, key);
		}

	}
}


/*======================================================================*
                            get_byte_from_kb_buf
 *----------------------------------------------------------------------*
 * 作用：从键盘缓冲区中读取下一个字节
 *======================================================================*/
PUBLIC t_8 get_byte_from_kb_buf()
{
	t_8 scan_code;

	while (kb_in.count <= 0)
	{
		/* 等待下一个字节到来 */
	}

	disable_int();

	scan_code = *(kb_in.p_tail);

	kb_in.p_tail++;
	if (kb_in.p_tail == kb_in.buf + KB_IN_BYTES)
	{
		kb_in.p_tail = kb_in.buf;
	}

	kb_in.count--;

	enable_int();

#ifdef __TINIX_DEBUG__
	disp_color_str("[", MAKE_COLOR(WHITE,BLUE));
	disp_int(scan_code);
	disp_color_str("]", MAKE_COLOR(WHITE,BLUE));
#endif

	return scan_code;
}

/*======================================================================*
                                 kb_wait
 *----------------------------------------------------------------------*
 * 作用：等待 8042 的输入缓冲区空
 *======================================================================*/
PRIVATE void kb_wait()
{
	t_8 kb_stat;

	do 
	{
		kb_stat = in_byte(KB_CMD);
	} 
	while (kb_stat & 0x02);
}

/*======================================================================*
                                 kb_ack
 *----------------------------------------------------------------------* 
 * 作用：等待 8042 的返回的ACK
 *======================================================================*/
PRIVATE void kb_ack()
{
	t_8 kb_read;

	do 
	{
		kb_read = in_byte(KB_DATA);
	} 
	while (kb_read =! KB_ACK);
}

/*======================================================================*
                                 set_leds
 *----------------------------------------------------------------------* 
 * 作用：设置三个键盘灯的状态
 *======================================================================*/
PRIVATE void set_leds()
{
	t_8 leds = (caps_lock << 2) | (num_lock << 1) | scroll_lock;

	kb_wait();
	out_byte(KB_DATA, LED_CODE);
	kb_ack();

	kb_wait();
	out_byte(KB_DATA, leds);
	kb_ack();
}

