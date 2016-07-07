// ; ==========================================
// ; proto.h
// ; 导出 klib.asm klib.c protect.c i8259.c 中的函数
// ; ==========================================

// #include "type.h"
// #include "const.h"

// klib.asm
PUBLIC void out_byte(t_port port, t_8 value);
PUBLIC t_8  in_byte(t_port port);

PUBLIC void	disable_int();
PUBLIC void	enable_int();

PUBLIC void disp_str(char *info);
PUBLIC void disp_color_str(char *info, int color);

// klib.c
PUBLIC t_bool is_alphanumeric(char ch);
PUBLIC void disp_int(int input);
PUBLIC void delay(int time);

// i8259.c
PUBLIC void init_8259A();
PUBLIC void put_irq_handler(int irq, t_pf_irq_handler handler);
PUBLIC void spurious_irq(int irq);

// protect.c
PUBLIC void init_prot();
PUBLIC void exception_handler(int vec_no, int err_code, int eip, int cs, int eflags);
PUBLIC t_32 seg2phys(t_16 seg);

PUBLIC void	disable_irq(int irq);
PUBLIC void	enable_irq(int irq);

// kernel.asm
PUBLIC void restart();

// main.c
PUBLIC void tinix_main();
PUBLIC void TestA();
PUBLIC void TestB();
PUBLIC void TestC();

/* clock.c */
PUBLIC void clock_handler(int irq);
PUBLIC void milli_delay(int milli_sec);
PUBLIC void init_clock();

/* proc.c */
PUBLIC void schedule();

/* keyboard.c */
PUBLIC void keyboard_handler(int irq);
PUBLIC void init_keyboard();
PUBLIC void keyboard_read();

/* tty.c */
PUBLIC void task_tty();
PUBLIC void in_process(TTY *p_tty, t_32 key);

/* console.c */
PUBLIC void init_screen(TTY* p_tty);
PUBLIC void out_char(CONSOLE* p_con, char ch);
PUBLIC void select_console(int nr_console);
PUBLIC void scroll_screen(CONSOLE* p_con, int direction);
PUBLIC t_bool is_current_console(CONSOLE* p_con);

/************************************************************************/
/*                        以下是系统调用相关                               */
/************************************************************************/

/* proc.c */
PUBLIC	int	sys_get_ticks();	/* t_sys_call */

/* syscall.asm */
PUBLIC	int	get_ticks();

// kernel.asm
PUBLIC	void sys_call();		/* t_pf_int_handler */
