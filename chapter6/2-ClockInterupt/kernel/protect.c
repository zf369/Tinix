// ==========================================
// klib.c
// 用C实现的基础函数
// ==========================================

#include "type.h"
#include "const.h"
#include "protect.h"
#include "proto.h"
#include "string.h"
#include "proc.h"
#include "global.h"

/* 本文件内函数声明 */
PRIVATE void init_idt_desc(unsigned char vector, t_8 desc_type, t_pf_int_handler handler, unsigned char privilege);
PRIVATE void init_descriptor(DESCRIPTOR * p_desc, t_32 base, t_32 limit, t_16 attribute);

/************************ 中断处理函数 *********************************/
// c中的函数声明不需要特别处理，无论是本文件的函数还是其他文件的函数，声明一下即可
// 不用像变量一样添加extern区分本文件的和其他文件定义的变量。
// 下面的这些中断函数有本文件的，也有在kernel.asm中用汇编定义的

// 系统中断处理函数
void divide_error();
void single_step_exception();
void nmi();
void breakpoint_exception();
void overflow();
void bounds_check();
void inval_opcode();
void copr_not_available();
void double_fault();
void copr_seg_overrun();
void inval_tss();
void segment_not_present();
void stack_exception();
void general_protection();
void page_fault();
void copr_error();
// 用户自定义中断（8529A的中断处理）处理函数
void hwint00();
void hwint01();
void hwint02();
void hwint03();
void hwint04();
void hwint05();
void hwint06();
void hwint07();
void hwint08();
void hwint09();
void hwint10();
void hwint11();
void hwint12();
void hwint13();
void hwint14();
void hwint15();


/*======================================================================*
                            init_prot
 *----------------------------------------------------------------------*
 * 作用：初始化IDT和8529
 *======================================================================*/
PUBLIC void init_prot()
{
	init_8259A();

	// 全部初始化成中断门(没有陷阱门)
	init_idt_desc(INT_VECTOR_DIVIDE, DA_386IGate, divide_error,             PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_DEBUG,  DA_386IGate, single_step_exception,    PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_NMI,    DA_386IGate, nmi,                      PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_BREAKPOINT, DA_386IGate, breakpoint_exception,	   PRIVILEGE_USER);
	init_idt_desc(INT_VECTOR_OVERFLOW,   DA_386IGate, overflow,                PRIVILEGE_USER);
	init_idt_desc(INT_VECTOR_BOUNDS,    DA_386IGate, bounds_check,          PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_INVAL_OP,  DA_386IGate, inval_opcode,          PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_COPROC_NOT, DA_386IGate, copr_not_available,	PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_DOUBLE_FAULT, DA_386IGate, double_fault,		PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_COPROC_SEG, DA_386IGate, copr_seg_overrun,		PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_INVAL_TSS, DA_386IGate, inval_tss,             PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_SEG_NOT, DA_386IGate, segment_not_present,     PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_STACK_FAULT, DA_386IGate, stack_exception,     PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_PROTECTION, DA_386IGate, general_protection,   PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_PAGE_FAULT, DA_386IGate, page_fault,           PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_COPROC_ERR, DA_386IGate, copr_error,           PRIVILEGE_KRNL);
	
	// Master 8529A产生的中断
	init_idt_desc(INT_VECTOR_IRQ0 + 0,	DA_386IGate, hwint00,			PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_IRQ0 + 1,	DA_386IGate, hwint01,			PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_IRQ0 + 2,	DA_386IGate, hwint02,			PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_IRQ0 + 3,	DA_386IGate, hwint03,			PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_IRQ0 + 4,	DA_386IGate, hwint04,			PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_IRQ0 + 5,	DA_386IGate, hwint05,			PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_IRQ0 + 6,	DA_386IGate, hwint06,			PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_IRQ0 + 7,	DA_386IGate, hwint07,			PRIVILEGE_KRNL);
	
	// Slave 8529A产生的中断
	init_idt_desc(INT_VECTOR_IRQ8 + 0,	DA_386IGate, hwint08,			PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_IRQ8 + 1,	DA_386IGate, hwint09,			PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_IRQ8 + 2,	DA_386IGate, hwint10,			PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_IRQ8 + 3,	DA_386IGate, hwint11,			PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_IRQ8 + 4,	DA_386IGate, hwint12,			PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_IRQ8 + 5,	DA_386IGate, hwint13,			PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_IRQ8 + 6,	DA_386IGate, hwint14,			PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_IRQ8 + 7,	DA_386IGate, hwint15,			PRIVILEGE_KRNL);

	/* 填充 GDT 中 TSS 这个描述符 */
	mem_set(&tss, 0, sizeof(tss));
	// zf: 这里只设置了ss0，没有设置esp0，esp0是在kernel.asm中的restart函数中设置的
	tss.ss0 = SELECTOR_KERNEL_DS;
	init_descriptor(&gdt[INDEX_TSS],
		            vir2phys(seg2phys(SELECTOR_KERNEL_DS), &tss),
		            sizeof(tss) - 1,
		            DA_386TSS);

	tss.iobase = sizeof(tss); /* 没有I/O许可位图 */


	// 填充 GDT 中进程的 LDT 的描述符
	init_descriptor(&gdt[INDEX_LDT_FIRST],
		            vir2phys(seg2phys(SELECTOR_KERNEL_DS), proc_table[0].ldts),
		            LDT_SIZE * sizeof(DESCRIPTOR) - 1,
		            DA_LDT);
}

/*======================================================================*
                            init_idt_desc
 *----------------------------------------------------------------------*
 * 作用：初始化IDT描述符
 *======================================================================*/
PRIVATE void init_idt_desc(unsigned char vector, t_8 desc_type, t_pf_int_handler handler, unsigned char privilege)
{
	GATE *p_gate = &idt[vector];
	t_32  base = (t_32)handler;

	/*
	t_16    offset_low;        // Offset Low
	t_16    selector;          // Selector
	t_8     dcount;            // 该字段只在调用门描述符中有效。
				               // 如果在利用调用门调用子程序时引起特权级的转换和堆栈的改变，
				               // 需要将外层堆栈中的参数复制到内层堆栈。
				               // 该双字计数字段就是用于说明这种情况发生时，要复制的双字参数的数量。
	t_8     attr;              // P(1) DPL(2) S(1) TYPE(4)
	t_16    offset_high;       // Offset High
	*/

	p_gate->offset_low = base & 0xFFFF;
	p_gate->selector = SELECTOR_KERNEL_CS;
	p_gate->dcount = 0;
	p_gate->attr = desc_type | (privilege << 5);
	p_gate->offset_high = (base >> 16) & 0xFFFF;
}

/*======================================================================*
                           init_descriptor
 *----------------------------------------------------------------------*
 作用：初始化段描述符
 *======================================================================*/
PRIVATE void init_descriptor(DESCRIPTOR * p_desc, t_32 base, t_32 limit, t_16 attribute)
{
	/*
	 t_16    limit_low;        // Limit
	 t_16    base_low;         // Base
	 t_8     base_mid;         // Base
	 t_8     attr1;            // P(1) DPL(2) DT(1) TYPE(4)
	 t_8     limit_high_attr2; // G(1) D(1) 0(1) AVL(1) LimitHight(4)
	 t_8     base_high;        // Base
	 */
	p_desc->limit_low = limit & 0xFFFF;    // 段界限 1		(2 字节)
	p_desc->base_low  = base & 0xFFFF;     // 段基址 1		(2 字节)
	p_desc->base_mid  = (base >> 16) & 0x0FF;     // 段基址 2		(1 字节)
	p_desc->attr1 = attribute & 0xFF;    // 属性 1
	p_desc->limit_high_attr2 = ((limit >> 16) & 0x0F) | ((attribute >> 8) & 0xF0); // 段界限 2 + 属性 2
	p_desc->base_high  = (base >> 24) & 0x0FF;     // 段基址 3		(1 字节)
}

/*======================================================================*
                           seg2phys
 *----------------------------------------------------------------------*
 作用：通过selector查找GDT，得到selector对应的描述符中存储的base
 *======================================================================*/
PUBLIC t_32 seg2phys(t_16 seg)
{
	// selector / 8 = 描述符在GDT中的index
	DESCRIPTOR *p_dest = &gdt[seg >> 3];

	return ((p_dest->base_high << 24) | (p_dest->base_mid << 16) | (p_dest->base_low));
}

/*======================================================================*
                            exception_handler
 *----------------------------------------------------------------------*
 * 作用：异常处理
 *======================================================================*/
PRIVATE char err_description[][64] = {
	"#DE Divide Error",
	"#DB RESERVED",
	"—  NMI Interrupt",
	"#BP Breakpoint",
	"#OF Overflow",
	"#BR BOUND Range Exceeded",
	"#UD Invalid Opcode (Undefined Opcode)",
	"#NM Device Not Available (No Math Coprocessor)",
	"#DF Double Fault",
	"    Coprocessor Segment Overrun (reserved)",
	"#TS Invalid TSS",
	"#NP Segment Not Present",
	"#SS Stack-Segment Fault",
	"#GP General Protection",
	"#PF Page Fault",
	"—  (Intel reserved. Do not use.)",
	"#MF x87 FPU Floating-Point Error (Math Fault)",
	"#AC Alignment Check",
	"#MC Machine Check",
	"#XF SIMD Floating-Point Exception"
};

PUBLIC void exception_handler(int vec_no, int err_code, int eip, int cs, int eflags)
{
    int i;
    int text_color = 0x74; // 灰底红字

    /* 通过打印空格的方式清空屏幕的前五行，并把 disp_pos 清零 */
    disp_pos = 0;
    for (i = 0; i < 80 * 5; i++)
    {
    	disp_str(" ");
    }
    disp_pos = 0;

    disp_color_str("Exception! --> ", text_color);
    disp_color_str(err_description[vec_no], text_color);
    disp_color_str("\n\n", text_color);

    disp_color_str("EFLAGS:", text_color);
    disp_int(eflags);

	disp_color_str(" CS:", text_color);
    disp_int(cs);

    disp_color_str(" EIP:", text_color);
    disp_int(eip);

    if (err_code != 0xFFFFFFFF)
    {
    	disp_color_str(" Error code:", text_color);
	    disp_int(err_code);
    }
}