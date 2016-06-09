// ; ==========================================
// ; proto.h
// ; 导出 klib.asm klib.c protect.c i8259.c 中的函数
// ; ==========================================

// #include "type.h"
// #include "const.h"

// klib.asm
PUBLIC void out_byte(t_port port, t_8 value);
PUBLIC t_8  in_byte(t_port port);

PUBLIC void disp_str(char *info);
PUBLIC void disp_color_str(char *info, int color);

// klib.c
PUBLIC void disp_int(int input);
PUBLIC void delay(int time);

// i8259.c
PUBLIC void init_8259A();
PUBLIC void spurious_irq(int irq);

// protect.c
PUBLIC void init_prot();
PUBLIC void exception_handler(int vec_no, int err_code, int eip, int cs, int eflags);
PUBLIC t_32 seg2phys(t_16 seg);

// kernel.asm
PUBLIC void restart();

// main.c
PUBLIC void tinix_main();
PUBLIC void TestA();

