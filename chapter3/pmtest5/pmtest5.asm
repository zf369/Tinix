; ==========================================
; pmtest5.asm
; 测试从DPL=0代码进入DPL=3代码以后，再通过调用门进入DPL=0的代码
; ==========================================

%include "pm.inc"  ; 常量, 宏, 以及一些说明

org    0100h
       jmp    LABEL_BEGIN     ; 接下来的是gdt数据部分，不是代码，必须要跳过去


; ===================   GDT   =======================

[SECTION .gdt]
; GDT
;                                     段基址                段界限    属性
LABEL_GDT:            Descriptor          0,                   0,    0        ; 空描述符
LABEL_DESC_NORMAL:	  Descriptor	      0,              0ffffh, DA_DRW	  ; Normal描述符
LABEL_DESC_CODE32:    Descriptor          0,    SegCode32Len - 1, DA_C + DA_32 ; 非一致代码段, 32位代码段
LABEL_DESC_CODE16:    Descriptor          0,              0ffffh, DA_C         ; 非一致代码段, 16位代码段
LABEL_DESC_CODE_DEST: Descriptor          0,  SegCodeDestLen - 1, DA_C + DA_32 ; 非一致代码段, 32位代码段，这一个新增的段是通过调用门跳转过来的
LABEL_DESC_CODE_RING3:Descriptor          0, SegCodeRing3Len - 1, DA_C + DA_32 + DA_DPL3 ; 非一致代码段, 32位代码段，DPL=3
LABEL_DESC_DATA:	  Descriptor	      0,	     DataLen - 1, DA_DRW       ; Data
LABEL_DESC_STACK:	  Descriptor	      0,          TopOfStack, DA_DRWA + DA_32	; Stack, 32 位
LABEL_DESC_STACK3:    Descriptor          0,         TopOfStack3, DA_DRWA + DA_32 + DA_DPL3   ; Stack, 32 位, DPL=3
LABEL_DESC_LDT:       Descriptor          0,          LDTLen - 1, DA_LDT ; LDT
LABEL_DESC_TSS:       Descriptor          0,          TSSLen - 1, DA_386TSS ; TSS
LABEL_DESC_VIDEO:     Descriptor    0B8000h,              0ffffh, DA_DRW + DA_DPL3 ; 数据段，显存首地址，为了让DPL=3的代码能够访问该数据段，将DPL改成3

; 门                                目标选择子,       偏移,   DCount,           属性
LABEL_CALL_GATE_TEST: Gate  SelectorCodeDest,         0,        0,  DA_386CGate + DA_DPL3 ; 因为想使用DPL3的代码通过"调用门"调用DPL0的代码，调用门的规则是：DPL_B <= CPL <= DPL_Gate，所以将调用门的DPL也改成3

; GDT END

GdtLen        equ    $ - LABEL_GDT    ; GDT长度
GdtPtr        dw     GdtLen - 1       ; GDT界限=GdtLen-1？段界限=段内的最大偏移，从0开始。
              dd     0                ; GDT基地址，这个是暂时填0，后面ds确定了以后再填充

; GDT 选择子
SelectorNormal		equ	LABEL_DESC_NORMAL	   - LABEL_GDT
SelectorCode32		equ	LABEL_DESC_CODE32	   - LABEL_GDT
SelectorCode16		equ	LABEL_DESC_CODE16	   - LABEL_GDT
SelectorCodeDest    equ LABEL_DESC_CODE_DEST   - LABEL_GDT
SelectorCodeRing3   equ LABEL_DESC_CODE_RING3  - LABEL_GDT + SA_RPL3
SelectorData		equ	LABEL_DESC_DATA		   - LABEL_GDT
SelectorStack		equ	LABEL_DESC_STACK	   - LABEL_GDT
SelectorStack3      equ LABEL_DESC_STACK3      - LABEL_GDT + SA_RPL3
SelectorLDT 		equ	LABEL_DESC_LDT		   - LABEL_GDT
SelectorTSS         equ LABEL_DESC_TSS         - LABEL_GDT
SelectorVideo		equ	LABEL_DESC_VIDEO	   - LABEL_GDT

SelectorCallGateTest  equ LABEL_CALL_GATE_TEST - LABEL_GDT + SA_RPL3

; END of [SECTION .gdt]


; ===================   数据段   =======================

[SECTION .data1]    ; 数据段

ALIGN    32
[BITS    32]

LABEL_DATA:

SPValueInRealMode    dw    0

PMMessage:      db    "In Protect Mode now. ^-^", 0  ; 进入保护模式以后显示该字符串
OffsetPMMessage     equ    (PMMessage - $$)

StrTest:		db	"ABCDEFGHIJKLMNOPQRSTUVWXYZ", 0
OffsetStrTest		equ	   (StrTest - $$)

DataLen         equ    ($ - LABEL_DATA)

; END of [SECTION .data1]



; ===================   全局堆栈段   =======================
[SECTION .gs]

ALIGN    32
[BITS    32]

LABEL_STACK:
	times    512     db  0

TopOfStack    equ    ($ - LABEL_STACK - 1)

; END of [SECTION .gs]



; ===================   堆栈段ring3，DPL=3   =======================
[SECTION .s3]

ALIGN    32
[BITS    32]

LABEL_STACK3:
    times    512     db  0

TopOfStack3   equ    ($ - LABEL_STACK3 - 1)

; END of [SECTION .s3]


; ===================   TSS   =======================
[SECTION .tss]
ALIGN    32
[BITS    32]

LABEL_TSS:
        ; 链接字段   链接字段安排在TSS内偏移0开始的双字中，其高16位未用。
        ; 在起链接作用时，低16位保存前一任务的TSS描述符的选择子。   
        ; 如果当前的任务由段间调用指令CALL或中断/异常而激活，那么链接字段保存被挂起任务的 TSS的选择子，
        ; 且标志寄存器EFLAGS中的NT位被置1，使链接字段有效。
        ; 在返回时，由于NT标志位为1，返回指令RET或中断返回指令IRET将使得控制沿链接字段所指恢复到链上的前一个任务。
        DD     0                ; Back

        ; 内层堆栈指针区域
        DD     TopOfStack       ; 特权级0的esp
        DD     SelectorStack    ; 特权级0的ss
        DD     0                ; 特权级1的esp
        DD     0                ; 特权级1的ss
        DD     0                ; 特权级2的esp
        DD     0                ; 特权级2的ss
        
        ; 地址映射寄存器区域
        ; TSS的地址映射寄存器区域由位于偏移1CH处的双字字段(CR3)和位于偏移60H处的字字段(LDTR)组成。
        ; 在任务切换时，处理器自动从要执行任务的TSS中取出这两个字段，分别装入到寄存器CR3和LDTR。
        ; 这样就改变了虚拟地址空间到物理地址空间的映射。 
        DD     0                ; CR3

        ; 寄存器保存区域 位于TSS内偏移20H至5FH处，用于保存通用寄存器、段寄存器、指令指针和标志寄存器。
        ; 当TSS对应的任务正在执行时，保存区域是未定义的；
        ; 在当前任务被切换出时，这些寄存器的当前值就保存在该区域。
        ; 当下次切换回原任务时，再从保存区域恢复出这些寄存器的值，使处理器恢复成换出前的状态，最终能够恢复执行。
        ; 各通用寄存器对应一个32位的双字，指令指针和标志寄存器各对应一个32位的双字；
        ; 各段寄存器也对应一个32位的双字，段寄存器中的选择子只有16位，安排在双字的低16位，高16位未用，一般应填为0。 
        DD     0               ; EIP
        DD     0               ; EFLAGS
        DD     0               ; EAX
        DD     0               ; ECX
        DD     0               ; EDX
        DD     0               ; EBX
        DD     0               ; ESP
        DD     0               ; EBP
        DD     0               ; ESI
        DD     0               ; EDI
        DD     0               ; ES
        DD     0               ; CS
        DD     0               ; SS
        DD     0               ; DS
        DD     0               ; FS
        DD     0               ; GS

        ; 地址映射寄存器区域
        ; TSS的地址映射寄存器区域由位于偏移1CH处的双字字段(CR3)和位于偏移60H处的字字段(LDTR)组成。 
        DD     0               ; LDT

        ; 在TSS内偏移64H处的字是为任务提供的特别属性。在80386中，只定义了一种属性，即调试陷阱。
        ; 该属性是字的最低位，用T表示。该字的其它位置被保留，必须被置为0。
        ; 在发生任务切换时，如果进入任务的T位为1，那么在任务切换完成之后，新任务的第一条指令执行之前产生调试陷阱。 
        DW     0               ; 调试陷阱标志

        ; 为了实现输入/输出保护，要使用I/O许可位图。任务使用的I/O许可位图也存放在TSS中，作为TSS的扩展部分。
        ; 在TSS内偏移66H处的字用于存放I/O许可位图在TSS内的偏移(从TSS开头开始计算)。
        DW  $ - LABEL_TSS + 2  ; I/O位图基址

        DB   0ffh              ; I/O位图结束标志

TSSLen    equ    ($ - LABEL_TSS)

; End of [SECTION .tss]


; ===================   16位代码段   =======================

[SECTION .s16]    ; 16位代码段，实模式
[BITS  16]

LABEL_BEGIN:
        mov    ax, cs
        mov    ds, ax
        mov    es, ax
        mov    ss, ax
        mov    sp, 0100h       

        mov [LABEL_GO_BACK_TO_REAL + 3], ax
        mov [SPValueInRealMode], sp

        ; 填充16位代码段描述符的段基址
        mov    ax, cs
        movzx  eax, ax    ;movzx其实就是将我们的源操作数取出来,然后置于目的操作数,目的操作数其余位用0填充。
        shl    eax, 4
        add    eax, LABEL_SEG_CODE16  ; 段基址 = cs + offset？
        mov	   word [LABEL_DESC_CODE16 + 2], ax
	    shr	   eax, 16
	    mov	   byte [LABEL_DESC_CODE16 + 4], al
	    mov	   byte [LABEL_DESC_CODE16 + 7], ah

        ; 填充32位代码段描述符的段基址
        xor    eax, eax        ; xor eax,eax与mov eax,0是一样的结果
        mov    ax, cs
        shl    eax, 4
        add    eax, LABEL_SEG_CODE32  ; 段基址 = cs + offset？
        mov	   word [LABEL_DESC_CODE32 + 2], ax
	    shr	   eax, 16
	    mov	   byte [LABEL_DESC_CODE32 + 4], al
	    mov	   byte [LABEL_DESC_CODE32 + 7], ah

        ; 初始化测试调用门的代码段描述符的段基址
        xor    eax, eax        ; xor eax,eax与mov eax,0是一样的结果
        mov    ax, ds
        shl    eax, 4
        add    eax, LABEL_SEG_CODE_DEST  ; 段基址 = ds + offset？
        mov    word [LABEL_DESC_CODE_DEST + 2], ax
        shr    eax, 16
        mov    byte [LABEL_DESC_CODE_DEST + 4], al
        mov    byte [LABEL_DESC_CODE_DEST + 7], ah

        ; 初始化数据段描述符的段基址
        xor    eax, eax        ; xor eax,eax与mov eax,0是一样的结果
        mov    ax, ds
        shl    eax, 4
        add    eax, LABEL_DATA  ; 段基址 = ds + offset？
        mov	   word [LABEL_DESC_DATA + 2], ax
	    shr	   eax, 16
	    mov	   byte [LABEL_DESC_DATA + 4], al
	    mov	   byte [LABEL_DESC_DATA + 7], ah

	    ; 初始化堆栈段描述符的段基址
        xor    eax, eax        ; xor eax,eax与mov eax,0是一样的结果
        mov    ax, ds
        shl    eax, 4
        add    eax, LABEL_STACK  ; 段基址 = ds + offset？
        mov	   word [LABEL_DESC_STACK + 2], ax
	    shr	   eax, 16
	    mov	   byte [LABEL_DESC_STACK + 4], al
	    mov	   byte [LABEL_DESC_STACK + 7], ah

        ; 初始化堆栈段(ring3)描述符的段基址
        xor    eax, eax        ; xor eax,eax与mov eax,0是一样的结果
        mov    ax, ds
        shl    eax, 4
        add    eax, LABEL_STACK3 ; 段基址 = ds + offset？
        mov    word [LABEL_DESC_STACK3 + 2], ax
        shr    eax, 16
        mov    byte [LABEL_DESC_STACK3 + 4], al
        mov    byte [LABEL_DESC_STACK3 + 7], ah

        ; 初始化LDT描述符的段基址
        xor    eax, eax        ; xor eax,eax与mov eax,0是一样的结果
        mov    ax, ds
        shl    eax, 4
        add    eax, LABEL_LDT  ; 段基址 = ds + offset？
        mov    word [LABEL_DESC_LDT + 2], ax
        shr    eax, 16
        mov    byte [LABEL_DESC_LDT + 4], al
        mov    byte [LABEL_DESC_LDT + 7], ah

        ; 初始化LDT中的LABEL_LDT_DESC_CODEA描述符的段基址
        xor    eax, eax        ; xor eax,eax与mov eax,0是一样的结果
        mov    ax, ds
        shl    eax, 4
        add    eax, LABEL_CODE_A  ; 段基址 = ds + offset？
        mov    word [LABEL_LDT_DESC_CODEA + 2], ax
        shr    eax, 16
        mov    byte [LABEL_LDT_DESC_CODEA + 4], al
        mov    byte [LABEL_LDT_DESC_CODEA + 7], ah

        ; 填充32位代码段(Ring3)描述符的段基址
        xor    eax, eax        ; xor eax,eax与mov eax,0是一样的结果
        mov    ax, ds
        shl    eax, 4
        add    eax, LABEL_CODE_RING3  ; 段基址 = ds + offset？
        mov    word [LABEL_DESC_CODE_RING3 + 2], ax
        shr    eax, 16
        mov    byte [LABEL_DESC_CODE_RING3 + 4], al
        mov    byte [LABEL_DESC_CODE_RING3 + 7], ah

        ; 初始化 TSS 描述符
        xor    eax, eax        ; xor eax,eax与mov eax,0是一样的结果
        mov    ax, ds
        shl    eax, 4
        add    eax, LABEL_TSS  ; 段基址 = ds + offset？
        mov    word [LABEL_DESC_TSS + 2], ax
        shr    eax, 16
        mov    byte [LABEL_DESC_TSS + 4], al
        mov    byte [LABEL_DESC_TSS + 7], ah


	    ; 为加载 GDTR 作准备
	    xor	   eax, eax
	    mov	   ax, ds
	    shl	   eax, 4
	    add	   eax, LABEL_GDT		; eax <- gdt 基地址
	    mov	   dword [GdtPtr + 2], eax	; [GdtPtr + 2] <- gdt 基地址

	    ; 加载 GDTR
	    lgdt   [GdtPtr]

	    ; 关中断
	    cli

	    ; 打开地址线A20
	    in	   al, 92h       ; in al，92h 表示从92h号端口读入一个字节
	    or	   al, 00000010b
	    out	   92h, al       ; out 92h，al 表示向92h号端口写入一个字节

	    ; 准备切换到保护模式
	    mov    eax, cr0
	    or     eax, 1
	    mov    cr0, eax

	    ; 真正进入保护模式
	    jmp    dword SelectorCode32:0    ; 执行这一句会把 SelectorCode32 装入 cs, 并跳转到 SelectorCode32:0  处

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LABEL_REAL_ENTRY:		; 从保护模式跳回到实模式就到了这里
		mov    ax, cs
        mov    ds, ax
        mov    es, ax
        mov    ss, ax

        ; 将保存在SPValueInRealMode处的sp恢复
        mov sp, [SPValueInRealMode]

        ; 关闭地址线A20
	    in	   al, 92h       ; ┓
	    and	   al, 11111101b ; ┣ 关闭 A20 地址线
	    out	   92h, al       ; ┛

	    ; 开中断
	    sti

	    ; 回到DOS
	    mov    ax, 4c00h    ; 4CH号功能——带返回码结束程序。AL=返回码
	    int    21h          ; INT 21是计算机中断的一种，不同的AH值表示不同的中断功能。

; END of [SECTION .s16]


; ===================   32位代码段   =======================

[SECTION .s32]    ; 32位代码段，由实模式跳入
[BITS  32]

LABEL_SEG_CODE32:
	    mov    ax, SelectorData
        mov    ds, ax          ; 数据段选择子->ds，保护模式的段地址都是Selector

        mov    ax, SelectorVideo
        mov    gs, ax          ; 视频段选择子(目的)

        mov    ax, SelectorStack
        mov    ss, ax          ; 堆栈段选择子

        mov    esp, TopOfStack ; esp 指向栈底


        ; 下面显示一个字符串
        mov    ah, 0Ch    ; 0000: 黑底    1100: 红字

        xor    esi, esi
        xor    edi, edi

        mov    esi, OffsetPMMessage      ; 将PMMessage字符串的offset写入esi
        mov    edi, (80 * 10 + 0) * 2    ; 目标是屏幕第 10 行, 第 0 列。

        cld    ; cld使DF 复位，即是让DF=0，std使DF置位，即DF=1.

.1:
        lodsb  ; 其中LODSB是读入AL,LODSW是读入AX中,然后SI自动增加或减小1或2位.

        test    al, al    ; TEST AX,BX 与 AND AX,BX 命令有相同效果
        jz      .2

        mov    [gs:edi], ax
        add    edi, 2

        jmp    .1

.2:     ; 显示PMMessage完毕

        call    DispReturn     ; 换行

        ; Load TSS
        mov     ax, SelectorTSS
        ; LTR - 加载任务寄存器
        ltr     ax  ; TR，16BIT，用于存放TSS在GDT中的索引


                                     ; | ........|
        push    SelectorStack3       ; |    ss   |
        push    TopOfStack3          ; |   esp   | 
        push    SelectorCodeRing3    ; |    cs   | 
        push    0                    ; |   eip   | <--- ret执行之前的esp
                                     ; | ........| 

        retf                         ; Ring0 -> Ring3，历史性转移！将打印数字 '3'。

; ------------------------------------------------------------------------
; DispReturn: 模拟一个回车的显示（改变edi寄存器，让edi的值变成下一行的开头的值）
;   edi 始终指向要显示的下一个字符的位置
; 被改变的寄存器:
;   edi

; 其中edi始终指向要显示的下一个字符的位置。例如：
; mov    edi, (80 * 10 + 0) * 2    ; 屏幕第 10 行, 第 0 列。

; 80*25彩色字模式的显示显存在内存中的地址为B8000h~BFFFH,共32k.向这个地址写入的内容立即显示在屏幕上边.
; 在80*25彩色字模式 下共可以显示25行,每行80字符,每个字符在显存中占两个字节,第一个字节是字符的ASCII码.
; 第二字节是字符的属性，(80字符占160个字节）。
; ------------------------------------------------------------------------

DispReturn:
        push    eax
        push    ebx

        mov    eax, edi

        ; eax / 160 执行后al＝当前行号 
        mov    bl, 160
        div    bl         ;除数位数    隐含的被除数    商    余数    举例
                          ; 8位           AX        AL    AH    DIV  BH
                          ; 16位        DX-AX       AX    DX    DIV  BX
                          ; 32位       EDX-EAX     EAX   EDX    DIV  ECX

        and    eax, 0FFh  ; 只保留行号，列号清0，因为余数在AH中，而余数就是列号？？
        inc    eax        ; eax+＝1，使eax为当前行的下一行
        
        ; eax * 160，eax为当前行的下一行的开始
        mov    bl, 160
        mul    bl         ;乘数位数    隐含的被乘数    乘积的存放位置     举例
                          ; 8位         AL              AX          MUL  BL
                          ; 16位        AX             DX-AX        MUL  BX
                          ; 32位        EAX           EDX-EAX       MUL  ECX

        ; 使edi指向当前行的下一行的开始
        mov    edi, eax

        pop    ebx
        pop    eax

        ret
; DispReturn 结束---------------------------------------------------------

SegCode32Len    equ    ($ - LABEL_SEG_CODE32)

; END of [SECTION .s32]


; ===================   调用门的目标段 32位代码段   =======================
[SECTION .sdest]
[BITS    32]

LABEL_SEG_CODE_DEST:
        mov    ax, SelectorVideo
        mov    gs, ax          ; 视频段选择子(目的)

        ; 下面显示一个字符串
        mov    ah, 0Fh    ; 0000: 黑底    1111: 白字
        mov    al, 'Z'
        mov    edi, (80 * 12 + 9) * 2    ; 目标是屏幕第 12 行, 第 10 列。

        mov    [gs:edi], ax

        ; 使用jmp跳入LDT中代码
        ; 载入LDT
        mov    ax, SelectorLDT
        lldt   ax        
        ; 跳转到LDT中的局部任务
        jmp    SelectorLDTCodeA:0

        ; ret和retf：这两个指令的功能都是调用返回。
        ; 1. ret在返回时只从堆栈中取得EIP；retf中的字母f表示far，即段间转移返回，要从堆栈中取出EIP和CS。
        ; 2. 两个指令都可以带参数，表示发生过程调用时参数的个数，返回时要从堆栈中退出相应个数的参数。
        ; 3. 恢复CS时，如果发现将 发生特权级变化（当前CS的低2位不等于从堆栈中取得的新的CS值的低2位。由跳转的相关理论可知，只有跳转到非一致代码段时才会发生特权级变化，那么， 也只有从非一致代码段返回时才会发生特权级变化的返回），则还要从调用者堆栈中取得ESP和SS恢复到相应寄存器中，也即恢复调用者堆栈。
        retf    ; 这里由于使用的是 call seg:offset 的方式跳转过来的，所以使用retf

SegCodeDestLen    equ    ($ - LABEL_SEG_CODE_DEST)

; END of [SECTION .sdest]


; ------------------------------------------------------------------------
; 从保护模式跳转实模式前，需要加载一个合适的描述符选择子到有关的段寄存器，
; 以使对应段描述符高速缓冲寄存器中含有合适的段界限和属性
; 段界限显然是64K，即0ffffh(因为实模式下所有的段最大只能是16bit)，属性应该是DA_DRW，即可读写数据段
; 不能从32位代码段返回实模式，只能从16位代码段中返回。
; 因为无法实现从32位代码段返回时cs高速缓冲寄存器中的属性符合实模式的要求(实模式不能改变段属性)。

; 实模式下，段寄存器含有段值，处理器引用相应的某个段寄存器并将其值乘以16，形成20位的段基地址。
; 在保护模式下，段寄 存器含有段选择子，处理器要使用选择子所指定的描述符中的基地址等信息。
; 为了避免在每次存储器访问时，都要访问 描述符表而获得对应的段描述符，从80286开始每个段寄存器都配有一个高速缓冲寄存器，
; 称之为段描述符高速缓冲寄存器 或描述符投影寄存器，
; 对程序员而言 它是不可见的。每当把一个选择子装入到某个段寄存器时，处理器自动从描述符表中取出相应的描述符，
; 把描述符中的信息保存到对应的高速缓冲寄存器中。
; 此后对 该段访问时，处理器都使用对应高速缓冲寄存器中的描述符信息，而不用再从描述符表中取描述符。

; 新增的Normal描述符，段界限64K，属性DA_DRW，
; 在返回实模式之前把对应选择子SelectorNormal加载到ds、es和ss正好合适。

; ------------------------------------------------------------------------

; ===================   16位代码段   =======================

; 16 位代码段. 由 32 位代码段跳入, 跳出后到实模式
; 不能从32位保护模式直接跳回实模式，需要先从32位代码段跳到16位代码段，设置寄存器，再跳回实模式

[SECTION .s16code]
ALIGN    32
[BITS    16]

LABEL_SEG_CODE16:
    ; 先将保护模式中使用的寄存器都使用SelectorNormal设置一下
    ; 好像是让高速寄存器含有合适的段界限和属性
    
    ; zf: 测试一下不给寄存器设置SelectorNormal是否能返回实模式???
    ; 测试结果，不设置寄存器不能跳回到实模式
    mov    ax, SelectorNormal
    mov    ds, ax
    mov    es, ax
    mov    fs, ax
    mov    gs, ax
    mov    ss, ax
    
    mov    eax, cr0
    and    al, 11111110b
    mov    cr0, eax

LABEL_GO_BACK_TO_REAL:
    jmp    0:LABEL_REAL_ENTRY    ; 这里是跳回实模式，其实就是 jmp cs:offset
                                 ; 不过cs设置成0了，但是在97行代码处，将该处的0填充成了实模式下cs的值。


Code16Len    equ    ($ - LABEL_SEG_CODE16)

; END of [SECTION .s16code]


; ===================   LDT   =======================

[SECTION .ldt]
ALIGN    32

LABEL_LDT:
;                                     段基址                段界限    属性
LABEL_LDT_DESC_CODEA: Descriptor          0,        CodeALen - 1, DA_C + DA_32   ; 非一致代码段, 32位代码段
; LDT END

LDTLen    equ    ($ - LABEL_LDT)

; LDT选择子，LDT的选择子必须把TI位设为1，这样才是从LDT中查找描述符
SelectorLDTCodeA    equ LABEL_LDT_DESC_CODEA - LABEL_LDT + SA_TIL

; END of [SECTION .ldt]


; ===================   LDT，32位代码段   =======================
[SECTION .la]
ALIGN   32
[BITS   32]

LABEL_CODE_A:
        mov    ax, SelectorVideo
        mov    gs, ax          ; 视频段选择子(目的)

        ; 下面显示一个字符
        mov    ah, 0Ch    ; 0000: 黑底    1100: 红字
        mov    al, 'F'
        mov    edi, (80 * 12 + 10) * 2    ; 目标是屏幕第 12 行, 第 10 列。

        mov    [gs:edi], ax

        ; 跳转到16位代码段
        jmp    SelectorCode16:0

CodeALen    equ    ($ - LABEL_CODE_A)

; END of [SECTION .la]



; ===================   CodeRing3，32位代码段，从ring0跳转过来   =======================
[SECTION .ring3]
ALIGN    32
[BITS    32]

LABEL_CODE_RING3:
        mov    ax, SelectorVideo
        mov    gs, ax          ; 视频段选择子(目的)

        ; 下面显示一个字符
        mov    ah, 0Ch    ; 0000: 黑底    1100: 红字
        mov    al, '3'
        mov    edi, (80 * 14 + 10) * 2    ; 目标是屏幕第 14 行, 第 10 列。

        mov    [gs:edi], ax

        ; 测试调用门(CPL=3, DPL_Gate=3, RPL=3, 目标代码的DPL=0，因此有特权变化，需要TSS，否则无法跳转)
        call   SelectorCallGateTest:0

        jmp    $  ; 无限循环

SegCodeRing3Len    equ    ($ - LABEL_CODE_RING3)

; END of [SECTION .ring3]
