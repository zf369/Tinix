; ==========================================
; kernel.asm
; 重新设置了GDT，并且进行了跳转
;
; 编译链接方法 必须在linux下执行ld，生成可执行文件在linux下不能执行了，因为这段汇编代码在linux下执行没有效果。):
;
; 在linux下使用make命令
; ==========================================

%include "sconst.inc"

; 导入c中定义的函数
extern cstart
extern tinix_main
extern exception_handler
extern spurious_irq

; 导入全局变量
extern gdt_ptr
extern idt_ptr
extern p_proc_ready
extern tss
extern disp_pos

; 'BITS'指定代码是被设计运行在 16 位模式的处理器上还是运行 在 32 位模式的处理器上
; 大多数情况下,你可能不需要显式地指定'BITS'。
; 'aout','coff','elf'和 'win32'目标文件格式都是被设计用在 32 位操作系统上的,它们会让 NASM 缺 省选择 32 位模式。
; TEST: 之前一直没有bits 32，去掉试试？
; zf: 测试结果，可以去掉
bits 32

; --------------------------------- BSS ---------------------------------
; bssBSS（Block Started by Symbol）通常是指用来存放程序中未初始化的全局变量和静态变量的一块内存区域。
; 注意和数据段的区别，BSS存放的是未初始化的全局变量和静态变量，数据段存放的是初始化后的全局变量和静态变量。

[section .bss]

;  "RESB", "RESW", "RESD", "RESQ" and "REST"被设计用在模块的 BSS 段中：
; 它们声明未初始化的存储空间。每一个带有单个操作数，用来表明字节数，字数，或双字数或其它的需要保留单位。
StackSpace    resb    2 * 1024    ; 保留2k的栈空间
StackTop:                         ; 栈顶


; --------------------------------- 代码段 ---------------------------------
[section .text]

global _start    ; 我们必须导出 _start 这个入口，以便让链接器识别。

global restart   ; 导出restart，该函数用来最开始从内核态切换到用户态

; 导出中断处理函数
global  divide_error
global  single_step_exception
global  nmi
global  breakpoint_exception
global  overflow
global  bounds_check
global  inval_opcode
global  copr_not_available
global  double_fault
global  copr_seg_overrun
global  inval_tss
global  segment_not_present
global  stack_exception
global  general_protection
global  page_fault
global  copr_error
global  hwint00
global  hwint01
global  hwint02
global  hwint03
global  hwint04
global  hwint05
global  hwint06
global  hwint07
global  hwint08
global  hwint09
global  hwint10
global  hwint11
global  hwint12
global  hwint13
global  hwint14
global  hwint15



_start:
    
    ;***************************************************************
    ; 内存看上去是这样的：
    ;              ┃                                    ┃
    ;              ┃                 .                  ┃
    ;              ┃                 .                  ┃
    ;              ┃                 .                  ┃
    ;              ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
    ;              ┃■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■┃
    ;              ┃■■■■■■■■■■■ Page  Tables ■■■■■■■■■■■┃
    ;              ┃■■■■■■■■■■■(大小LOADER决定)■■■■■■■■■■┃
    ;    00201000h ┃■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■┃ PageTblBase
    ;              ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
    ;              ┃■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■┃
    ;    00200000h ┃■■■■■■■■■ Page Directory Table ■■■■■┃ PageDirBase  <- 2M
    ;              ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
    ;              ┃□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□┃
    ;       F0000h ┃□□□□□□□□□□□□ System ROM □□□□□□□□□□□□┃
    ;              ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
    ;              ┃□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□┃
    ;       E0000h ┃□□□□□ Expansion of system ROM □□□□□□┃
    ;              ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
    ;              ┃□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□┃
    ;       C0000h ┃□□□□□Reserved for ROM expansion□□□□□┃
    ;              ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
    ;              ┃□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□┃ B8000h ← gs
    ;       A0000h ┃□□□□□ Display adapter reserved □□□□□┃
    ;              ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
    ;              ┃□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□┃
    ;       9FC00h ┃□□ extended BIOS data area (EBDA) □□┃
    ;              ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
    ;              ┃■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■┃
    ;       90000h ┃■■■■■■■■■■■■■ LOADER.BIN ■■■■■■■■■■■┃ somewhere in LOADER ← esp
    ;              ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
    ;              ┃■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■┃
    ;       80000h ┃■■■■■■■■■■■ KERNEL.BIN ■■■■■■■■■■■■■┃
    ;              ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
    ;              ┃■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■┃
    ;       30000h ┃■■■■■■■■■■■■■■ KERNEL ■■■■■■■■■■■■■■┃ 30400h ← KERNEL 入口
    ;              ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
    ;              ┃                                    ┃
    ;        7E00h ┃              F  R  E  E            ┃
    ;              ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
    ;              ┃■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■┃
    ;        7C00h ┃■■■■■■■■■■■ BOOT  SECTOR ■■■■■■■■■■■┃
    ;              ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
    ;              ┃                                    ┃
    ;         500h ┃              F  R  E  E            ┃
    ;              ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
    ;              ┃□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□┃
    ;         400h ┃□□□ ROM BIOS parameter area □□□□□□□□┃
    ;              ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
    ;              ┃◇◇◇◇◇◇◇◇◇◇◇◇◇◇◇◇◇◇◇◇◇◇◇◇◇◇◇◇◇◇◇◇◇◇◇◇┃
    ;           0h ┃◇◇◇◇◇◇◇◇◇◇ Int  Vectors ◇◇◇◇◇◇◇◇◇◇◇◇┃
    ;              ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ ← cs, ds, es, fs, ss
    ;
    ;
    ;       ┏━━━┓            ┏━━━┓
    ;       ┃■■■┃ Tinix Used ┃□□□┃ 不能使用的内存
    ;       ┗━━━┛            ┗━━━┛
    ;       ┏━━━┓            ┏━━━┓
    ;       ┃   ┃ free       ┃◇◇◇┃ 可以覆盖的内存
    ;       ┗━━━┛            ┗━━━┛
    ;
    ;***************************************************************
    ; GDT 以及相应的描述符是这样的：
	;
	;		                    Descriptors                      Selectors
	;              ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
	;              ┃         Dummy Descriptor           ┃
	;              ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
	;              ┃         DESC_FLAT_C    (0-4G)      ┃         8h = cs
	;              ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
	;              ┃         DESC_FLAT_RW   (0-4G)      ┃        10h = ds, es, fs, ss
	;              ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
	;              ┃         DESC_VIDEO                 ┃        18h = gs
	;              ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
	;
	; 注意! 在使用 C 代码的时候一定要保证 ds, es, ss 这几个段寄存器的值是一样的
	; 因为编译器有可能编译出使用它们的代码, 而编译器默认它们是一样的. 比如串拷贝操作会用到 ds 和 es.
    ;***************************************************************	

    ; 转移esp, 将esp从Loader中挪到kernel中
    mov    esp, StackTop    ; 栈在BSS段中

    mov    dword [disp_pos], 0

    mov    ah, 0Ch                         ; 0000: 黑底    1111: 白字
    mov    al, '1'
    mov    [gs:((80 * 5 + 39) * 2)], ax    ; 屏幕第 1 行, 第 39 列。

    ; 保存gdt寄存器到[gdt_ptr], gdt_ptr是一个数组，gdt_ptr就是这个数组的首地址
    ; SGDT/SIDT - 存储全局/中断描述符表格寄存器
    ; 将全局描述符表格寄存器 (GDTR) 或中断描述符表格寄存器 (IDTR) 中的内容存储到目标操作数。
    ; 目标操作数是指定 6 字节内存位置。
    sgdt   [gdt_ptr]

    ; cstart中改变了gdt_ptr，让它指向新的GDT 
    call   cstart

    mov    ah, 0Ch                         ; 0000: 黑底    1111: 白字
    mov    al, '2'
    mov    [gs:((80 * 5 + 41) * 2)], ax    ; 屏幕第 1 行, 第 39 列。

    ; 重新设置GDT
    lgdt   [gdt_ptr]

    ; 设置IDT
    lidt   [idt_ptr]

    ; “这个跳转指令强制使用刚刚初始化的结构”
    jmp    SELECTOR_KERNEL_CS:csinit

csinit:
    
    ; 产生一个#UD异常 - #UD Invalid Opcode (Undefined Opcode）无错误码
    ;ud2

    ; 产生一个#PF异常 - #PF Page Fault
    ;jmp    0x40:0

    ; 开中断，后面就可以响应键盘中断事件了
	;sti

    ; HLT 执行操作后, 使机器暂停工作, 使处理器CPU处于停机...
    ;hlt

    ; 使用ltr(load task register)命令设置task register
    xor    eax, eax
    mov    ax, SELECTOR_TSS
    ltr    ax

    ; 跳转 tinix_main 执行进程表初始化
    jmp    tinix_main

; --------------------------------- Master 8529 中断处理 ---------------------------------
%macro hwint_master 1
    push    %1
    call    spurious_irq
    add     esp, 4

    hlt
%endmacro

; TEST：对齐的目的是啥？？？改成32或者去掉？
; zf: 对齐的目的 You usually align data to get better performance.
; zf: 测试结果，将某一个中断改成32或者去掉后，能正常执行
ALIGN   16
hwint00:        ; Interrupt routine for irq 0 (the clock).
    iretd    ; 时钟中断，直接返回，后续进程调度需要在这里实现

ALIGN   16
hwint01:        ; Interrupt routine for irq 1 (keyboard)
    hwint_master    1

ALIGN   16
hwint02:        ; Interrupt routine for irq 2 (cascade!)
    hwint_master    2

ALIGN   16
hwint03:        ; Interrupt routine for irq 3 (second serial)
    hwint_master    3

ALIGN   16
hwint04:        ; Interrupt routine for irq 4 (first serial)
    hwint_master    4

ALIGN   16
hwint05:        ; Interrupt routine for irq 5 (XT winchester)
    hwint_master    5

ALIGN   16
hwint06:        ; Interrupt routine for irq 6 (floppy)
    hwint_master    6

ALIGN   16
hwint07:        ; Interrupt routine for irq 7 (printer)
    hwint_master    7


; --------------------------------- Master 8529 中断处理 ---------------------------------
%macro hwint_slave 1
    push    %1
    call    spurious_irq
    add     esp, 4

    hlt
%endmacro

ALIGN   16
hwint08:        ; Interrupt routine for irq 8 (realtime clock).
    hwint_slave 8

ALIGN   16
hwint09:        ; Interrupt routine for irq 9 (irq 2 redirected)
    hwint_slave 9

ALIGN   16
hwint10:        ; Interrupt routine for irq 10
    hwint_slave 10

ALIGN   16
hwint11:        ; Interrupt routine for irq 11
    hwint_slave 11

ALIGN   16
hwint12:        ; Interrupt routine for irq 12
    hwint_slave 12

ALIGN   16
hwint13:        ; Interrupt routine for irq 13 (FPU exception)
    hwint_slave 13

ALIGN   16
hwint14:        ; Interrupt routine for irq 14 (AT winchester)
    hwint_slave 14

ALIGN   16
hwint15:        ; Interrupt routine for irq 15
    hwint_slave 15



; --------------------------------- 异常处理 ---------------------------------
; 关于是否有错误码可以查看《自己动手写操作系统》P110行
; 中断和异常发生以后，EFLAGS、CS、EIP已经依次压入栈中

divide_error:
    push    0xFFFFFFFF  ; no err code
    push    0       ; vector_no = 0
    jmp exception

single_step_exception:
    push    0xFFFFFFFF  ; no err code
    push    1       ; vector_no = 1
    jmp exception

nmi:
    push    0xFFFFFFFF  ; no err code
    push    2       ; vector_no = 2
    jmp exception

breakpoint_exception:
    push    0xFFFFFFFF  ; no err code
    push    3       ; vector_no = 3
    jmp exception

overflow:
    push    0xFFFFFFFF  ; no err code
    push    4       ; vector_no = 4
    jmp exception

bounds_check:
    push    0xFFFFFFFF  ; no err code
    push    5       ; vector_no = 5
    jmp exception

inval_opcode:
    push    0xFFFFFFFF  ; no err code
    push    6       ; vector_no = 6
    jmp exception

copr_not_available:
    push    0xFFFFFFFF  ; no err code
    push    7       ; vector_no = 7
    jmp exception

double_fault:
    push    8       ; vector_no = 8
    jmp exception

copr_seg_overrun:
    push    0xFFFFFFFF  ; no err code
    push    9       ; vector_no = 9
    jmp exception

inval_tss:
    push    10      ; vector_no = A
    jmp exception

segment_not_present:
    push    11      ; vector_no = B
    jmp exception

stack_exception:
    push    12      ; vector_no = C
    jmp exception

general_protection:
    push    13      ; vector_no = D
    jmp exception

page_fault:
    push    14      ; vector_no = E
    jmp exception

copr_error:
    push    0xFFFFFFFF  ; no err code
    push    16      ; vector_no = 10h
    jmp exception

exception:
    ; EFLAGS、CS、EIP、error code、 vector NO 已经依次压入栈中
    call    exception_handler

    ; C调用约定是调用者恢复栈，所以exception_handler不会破坏栈
    ; 让栈顶指向 EIP，堆栈中从顶向下依次是：EIP、CS、EFLAGS
    add     esp, 4 * 2

    hlt

; ====================================================================================
;                                   restart
; ------------------------------------------------------------------------
; 作用：实现从ring0(内核态) >>>> ring1(用户态)
; ====================================================================================
restart:
    
    ; 栈顶指向就绪的进程表
    mov    esp, [p_proc_ready]

    ; 设置LDT，LDT的选择子存储在进程表中
    lldt   [esp + P_LDT_SEL]

    ; lea的英文解释是： Load Effective Address.
    ; mov ax , [address] 又有什么不同呢？其实他们都是等效的。 
    ; 实际上是一个偏移量可以是立即数，也可以是经过四则运算的结果，更省空间，更有效率
    lea    eax, [esp + P_STACKTOP]

    ; Ring1 -> Ring0 时: 
    ; CPU将R1的"ss, esp, eflags, cs, eip, 返回地址, 寄存器"依次压入TSS中的esp0指向的栈中，以备返回时使用。
    ; 因此，在从Ring0返回到Ring1之前，需要将esp0设置成指向进程表的正确位置。
    ; 这样下次中断发生时，CPU能将"ss, esp, eflags, cs, eip, 返回地址, 寄存器"保存到进程表中
    mov    dword [tss + TSS3_S_SP0], eax

    ; esp指向的是进程表起始位置，进程表结构体中最开始是STACK_FRAME结构，顺序存放了各个寄存器的值
    ; 顺序pop即可获取之前设置好的寄存器值
    pop    gs
    pop    fs
    pop    es
    pop    ds

    ; 弹出 EDI、ESI、EBP、EBX、EDX、ECX 及 EAX
    popad

    ; 跳过 "返回地址"
    add    esp, 4

    ; >>>>>>>> Ring0 -> Ring1 <<<<<<<<<<<
    iretd



