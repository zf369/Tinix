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

/*======================================================================*
                            init_8259A
 *----------------------------------------------------------------------*
 * 作用: 初始化8529A，等同于pmtest9.asm中的Init8529A函数
 *======================================================================*/
PUBLIC void init_8259A()
{
    out_byte(INT_M_CTL, 0x11);    // Master 8259, ICW1.
    out_byte(INT_S_CTL, 0x11);    // Slave  8259, ICW1.

    out_byte(INT_M_CTLMASK, INT_VECTOR_IRQ0);    // Master 8259, ICW2. 设置 '主8259' 的中断入口地址为 0x20.
    out_byte(INT_S_CTLMASK, INT_VECTOR_IRQ8);    // Slave  8259, ICW2. 设置 '从8259' 的中断入口地址为 0x28

    out_byte(INT_M_CTLMASK, 0x4);    // Master 8259, ICW3. IR2 对应 '从8259'.
    out_byte(INT_S_CTLMASK, 0x2);    // Slave  8259, ICW3. 对应 '主8259' 的 IR2.

    out_byte(INT_M_CTLMASK, 0x1);    // Master 8259, ICW4.
    out_byte(INT_S_CTLMASK, 0x1);    // Slave  8259, ICW4.

    out_byte(INT_M_CTLMASK, 0xFD);    // Master 8259, OCW1. 仅仅开启IR1键盘中断
    out_byte(INT_S_CTLMASK, 0xFF);    // Slave  8259, OCW1. 关闭从8529A的所有中断
}

/*======================================================================*
                            spurious_irq
 *----------------------------------------------------------------------*
 * 作用: print irq to screen
 *======================================================================*/
PUBLIC void spurious_irq(int irq)
{
    disp_str("spurious_irq: ");
    disp_int(irq);
    disp_str("\n");
}
