// ==========================================
// protect.h
// 定义了保护模式需要使用的结构体
// ==========================================

#ifndef _TINIX_PROTECT_H_
#define _TINIX_PROTECT_H_

// 存储段、系统段描述符: 8 bytes
typedef struct s_descriptor
{
	t_16    limit_low;        // Limit
	t_16    base_low;         // Base
	t_8     base_mid;         // Base
	t_8     attr1;            // P(1) DPL(2) DT(1) TYPE(4)
	t_8     limit_high_attr2; // G(1) D(1) 0(1) AVL(1) LimitHight(4)
	t_8     base_high;        // Base
} DESCRIPTOR;

// Gate 描述符: 8 bytes
typedef struct s_gate
{
	t_16    offset_low;        // Offset Low
	t_16    selector;          // Selector
	t_8     dcount;            // 该字段只在调用门描述符中有效。
				               // 如果在利用调用门调用子程序时引起特权级的转换和堆栈的改变，
				               // 需要将外层堆栈中的参数复制到内层堆栈。
				               // 该双字计数字段就是用于说明这种情况发生时，要复制的双字参数的数量。
	t_8     attr;              // P(1) DPL(2) S(1) TYPE(4)
	t_16    offset_high;       // Offset High
} GATE;

// TSS: TSS在任务切换过程中起着重要作用，通过它实现任务的挂起和恢复。
// 在任务切换过程中:
// 1. 处理器中各寄存器的当前值被自动保存到TR（Task Register 任务寄存器）所指定的TSS中；(CPU registers >>> TSS)
// 2. 下一任务的TSS的选择子被装入TR；(切换TSS)
// 3. 从TR所指定的TSS中取出各寄存器的值送到处理器的各寄存器中。(TSS >>> CPU registers)
// 由此可见，通过在TSS中保存任务现场各寄存器状态的完整映象，实现任务的切换。 
typedef struct s_tss
{
	/* 链接字段   链接字段安排在TSS内偏移0开始的双字中，其高16位未用。
     * 在起链接作用时，低16位保存前一任务的TSS描述符的选择子。   
     * 如果当前的任务由段间调用指令CALL或中断/异常而激活，那么链接字段保存被挂起任务的 TSS的选择子，
     * 且标志寄存器EFLAGS中的NT位被置1，使链接字段有效。 
     */
	t_32    backlink;

	/* 内层堆栈指针区域
     * 为了有效地实现保护，同一个任务在不同的特权级下使用不同的堆栈。
     * 例如，当从外层特权级3变换到内层特权级0时，任务使用的堆栈也同时从3级变换到0级堆栈；
     * 当从内层特权级0变换到外层特权级3时，任务使用的堆栈也同时从0级堆栈变换到3级堆栈。
     */
	t_32	esp0;		
	t_32	ss0;		
	t_32	esp1;
	t_32	ss1;
	t_32	esp2;
	t_32	ss2;

	/* 地址映射寄存器区域
     * TSS的地址映射寄存器区域由位于偏移1CH处的双字字段(CR3)和位于偏移60H处的字字段(LDTR)组成。
     * 在任务切换时，处理器自动从要执行任务的TSS中取出这两个字段，分别装入到寄存器CR3和LDTR。
     * 这样就改变了虚拟地址空间到物理地址空间的映射。 
     */
	t_32	cr3;

	/* 寄存器保存区域 位于TSS内偏移20H至5FH处，用于保存通用寄存器、段寄存器、指令指针和标志寄存器。
     * 当TSS对应的任务正在执行时，保存区域是未定义的；
     * 在当前任务被切换出时，这些寄存器的当前值就保存在该区域。
     * 当下次切换回原任务时，再从保存区域恢复出这些寄存器的值，使处理器恢复成换出前的状态，最终能够恢复执行。
     * 各通用寄存器对应一个32位的双字，指令指针和标志寄存器各对应一个32位的双字；
     * 各段寄存器也对应一个32位的双字，段寄存器中的选择子只有16位，安排在双字的低16位，高16位未用，一般应填为0
     */
	t_32	eip;
	t_32	flags;
	t_32	eax;
	t_32	ecx;
	t_32	edx;
	t_32	ebx;
	t_32	esp;
	t_32	ebp;
	t_32	esi;
	t_32	edi;
	t_32	es;
	t_32	cs;
	t_32	ss;
	t_32	ds;
	t_32	fs;
	t_32	gs;

	/* 地址映射寄存器区域
     * TSS的地址映射寄存器区域由位于偏移1CH处的双字字段(CR3)和位于偏移60H处的字字段(LDTR)组成。 
     */
	t_32	ldt;

	/* 其它字段
     * 在TSS内偏移64H处的字是为任务提供的特别属性。在80386中，只定义了一种属性，即调试陷阱。
     * 该属性是字的最低位，用T表示。该字的其它位置被保留，必须被置为0。
     * 在发生任务切换时，如果进入任务的T位为1，那么在任务切换完成之后，新任务的第一条指令执行之前产生调试陷阱。 
     */
	t_16	trap;

	/* 其它字段
     * 为了实现输入/输出保护，要使用I/O许可位图。任务使用的I/O许可位图也存放在TSS中，作为TSS的扩展部分。
     * 在TSS内偏移66H处的字用于存放I/O许可位图在TSS内的偏移(从TSS开头开始计算)。
     */
	t_16	iobase;	/* I/O位图基址大于或等于TSS段界限，就表示没有I/O许可位图 */
} TSS;

// GDT
// 描述符索引
#define	INDEX_DUMMY     0	// ┓
#define	INDEX_FLAT_C    1	// ┣ LOADER 里面已经确定了的.
#define	INDEX_FLAT_RW   2	// ┃
#define	INDEX_VIDEO     3	// ┛
#define	INDEX_TSS       4	// ┓ kernel设置的部分
#define	INDEX_LDT_FIRST 5	// ┛

/* 选择子 */
#define	SELECTOR_DUMMY         0		// ┓
#define	SELECTOR_FLAT_C     0x08		// ┣ LOADER 里面已经确定了的.
#define	SELECTOR_FLAT_RW    0x10		// ┃
#define	SELECTOR_VIDEO      (0x18+3)	// ┛<-- RPL=3
#define	SELECTOR_TSS        0x20        // TSS. 从外层跳到内层时 SS 和 ESP 的值从里面获得.
#define	SELECTOR_LDT_FIRST  0x28

#define	SELECTOR_KERNEL_CS	SELECTOR_FLAT_C
#define	SELECTOR_KERNEL_DS	SELECTOR_FLAT_RW
#define	SELECTOR_KERNEL_GS	SELECTOR_VIDEO

/* 每个任务有一个单独的 LDT, 每个 LDT 中的描述符个数: */
#define LDT_SIZE    2

// ;----------------------------------------------------------------------------
// ; 描述符类型值说明
// ; 其中:
// ;       DA_  : Descriptor Attribute
// ;       D    : 数据段
// ;       C    : 代码段
// ;       S    : 系统段
// ;       R    : 只读
// ;       RW   : 读写
// ;       A    : 已访问
// ;       其它 : 可按照字面意思理解
// ;----------------------------------------------------------------------------
/* 描述符类型值说明 */
#define	DA_32			0x4000	/* 32 位段				*/
#define	DA_LIMIT_4K		0x8000	/* 段界限粒度为 4K 字节    */

#define	DA_DPL0			0x00	/* DPL = 0				*/
#define	DA_DPL1			0x20	/* DPL = 1				*/
#define	DA_DPL2			0x40	/* DPL = 2				*/
#define	DA_DPL3			0x60	/* DPL = 3				*/

/* 存储段描述符类型值说明 */
#define	DA_DR			0x90	/* 存在的只读数据段类型值		*/
#define	DA_DRW			0x92	/* 存在的可读写数据段属性值		*/
#define	DA_DRWA			0x93	/* 存在的已访问可读写数据段类型值	*/

#define	DA_C			0x98	/* 存在的只执行代码段属性值		*/
#define	DA_CR			0x9A	/* 存在的可执行可读代码段属性值		*/
#define	DA_CCO			0x9C	/* 存在的只执行一致代码段属性值		*/
#define	DA_CCOR			0x9E	/* 存在的可执行可读一致代码段属性值	*/

/* 系统段描述符类型值说明 */
#define	DA_LDT			0x82	/* 局部描述符表段类型值			*/
#define	DA_TaskGate		0x85	/* 任务门类型值				*/
#define	DA_386TSS		0x89	/* 可用 386 任务状态段类型值	*/
#define	DA_386CGate		0x8C	/* 386 调用门类型值			*/
#define	DA_386IGate		0x8E	/* 386 中断门类型值			*/
#define	DA_386TGate		0x8F	/* 386 陷阱门类型值			*/

/* 选择子类型值说明 */
/* 其中, SA_ : Selector Attribute */
#define	SA_RPL_MASK	0xFFFC
#define	SA_RPL0		0
#define	SA_RPL1		1
#define	SA_RPL2		2
#define	SA_RPL3		3

#define	SA_TI_MASK	0xFFFB
#define	SA_TIG		0
#define	SA_TIL		4

/* 中断向量 */
#define	INT_VECTOR_DIVIDE            0x0
#define	INT_VECTOR_DEBUG             0x1
#define	INT_VECTOR_NMI               0x2
#define	INT_VECTOR_BREAKPOINT        0x3
#define	INT_VECTOR_OVERFLOW          0x4
#define	INT_VECTOR_BOUNDS            0x5
#define	INT_VECTOR_INVAL_OP          0x6
#define	INT_VECTOR_COPROC_NOT        0x7
#define	INT_VECTOR_DOUBLE_FAULT	     0x8
#define	INT_VECTOR_COPROC_SEG        0x9
#define	INT_VECTOR_INVAL_TSS         0xA
#define	INT_VECTOR_SEG_NOT           0xB
#define	INT_VECTOR_STACK_FAULT       0xC
#define	INT_VECTOR_PROTECTION        0xD
#define	INT_VECTOR_PAGE_FAULT        0xE
#define	INT_VECTOR_COPROC_ERR        0x10

/* 中断向量起始号 */
#define INT_VECTOR_IRQ0    0x20
#define INT_VECTOR_IRQ8    0x28

/* 宏 */
/* 线性地址 → 物理地址 */
// seg_base + vir
#define vir2phys(seg_base, vir) (t_32)(((t_32)seg_base) + (t_32)(vir))

#endif







