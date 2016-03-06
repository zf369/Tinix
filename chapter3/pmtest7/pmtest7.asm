; ==========================================
; pmtest6.asm
; 分页机制进阶，根据内存数量设计分页
; ==========================================

%include "pm.inc"  ; 常量, 宏, 以及一些说明

PageDirBase    equ    200000h ; PDE的开始地址：0x200000h(2M)
PageTblBase    equ    201000h ; PTE的开始地址：0x201000h(2M + 4k)

PageTestBase    equ    010h ; 测试修改页的起始地址

org    0100h
       jmp    LABEL_BEGIN     ; 接下来的是gdt数据部分，不是代码，必须要跳过去


; ===================   GDT   =======================

[SECTION .gdt]
; GDT
;                                     段基址                段界限    属性
LABEL_GDT:            Descriptor          0,                   0,    0        ; 空描述符
LABEL_DESC_NORMAL:	  Descriptor	      0,              0ffffh, DA_DRW	  ; Normal描述符
LABEL_DESC_PAGE_DIR:  Descriptor    PageDirBase,            4095, DA_DRW      ; Page Directory Entry，4k，段界限=4096-1， 段基址=0x0200000h
LABEL_DESC_PAGE_TBL:  Descriptor    PageTblBase,            1023, DA_DRW | DA_LIMIT_4K ; Page Table Entry，1024k，段基址=0x0201000h,段界限=1024-1， G=1表示界限粒度为4K字节，所以这里"段界限=(1024-1)*4k"，
LABEL_DESC_CODE32:    Descriptor          0,    SegCode32Len - 1, DA_C + DA_32 ; 非一致代码段, 32位代码段
LABEL_DESC_CODE16:    Descriptor          0,              0ffffh, DA_C         ; 非一致代码段, 16位代码段
LABEL_DESC_DATA:	  Descriptor	      0,	     DataLen - 1, DA_DRW       ; Data
LABEL_DESC_STACK:	  Descriptor	      0,          TopOfStack, DA_DRWA + DA_32	; Stack, 32 位
LABEL_DESC_VIDEO:     Descriptor    0B8000h,              0ffffh, DA_DRW       ; 数据段，显存首地址

; GDT END

GdtLen        equ    $ - LABEL_GDT    ; GDT长度
GdtPtr        dw     GdtLen - 1       ; GDT界限=GdtLen-1？段界限=段内的最大偏移，从0开始。
              dd     0                ; GDT基地址，这个是暂时填0，后面ds确定了以后再填充

; GDT 选择子
SelectorNormal		equ	LABEL_DESC_NORMAL	   - LABEL_GDT
SelectorPageDir     equ LABEL_DESC_PAGE_DIR    - LABEL_GDT
SelectorPageTbl     equ LABEL_DESC_PAGE_TBL    - LABEL_GDT
SelectorCode32		equ	LABEL_DESC_CODE32	   - LABEL_GDT
SelectorCode16		equ	LABEL_DESC_CODE16	   - LABEL_GDT
SelectorData		equ	LABEL_DESC_DATA		   - LABEL_GDT
SelectorStack		equ	LABEL_DESC_STACK	   - LABEL_GDT
SelectorVideo		equ	LABEL_DESC_VIDEO	   - LABEL_GDT

; END of [SECTION .gdt]


; ===================   数据段   =======================

[SECTION .data1]    ; 数据段

ALIGN    32
[BITS    32]

LABEL_DATA:

SPValueInRealMode    dw    0

PMMessage:      db    "In Protect Mode now. ^-^", 0  ; 进入保护模式以后显示该字符串
OffsetPMMessage     equ    (PMMessage - $$)

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
        ; 启动分页机制
        call   SetupPaging

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

        ; 到此停止，跳到16位代码段，准备回到实模式
        jmp SelectorCode16:0

; ------------------------------------------------------------------------
; SetupPaging: 启动分页机制
;
;     为了简化处理，所有线性地址对应相等的物理地址，即F(0x12345678) = 0x12345678
;     假设线性地址0x12345678，经过分页管理机制转换以后，对应的物理地址正好也是0x12345678
; ------------------------------------------------------------------------

SetupPaging:
        
        ; 初始化PDE
        mov    ax, SelectorPageDir    ; 该段首地址位PageDirBase
        mov    es, ax
        
        mov    ecx, 1024              ; 1024个表项
        
        xor    edi, edi
        xor    eax, eax

        ; PageTblBase是TBL的入口地址，32位，但是页表项是4k对齐，所以低20位必然位0
        ; 因此低20位可以用来标识该页的一些基本属性，后面3个属性是存在、可读写、用户表。
        mov    eax, PageTblBase | PG_P | PG_USU | PG_RWW

.1:
        ; STOSB/STOSW/STOSD 
        ; AL、AX、EAX中的Byte、word或dword存储到"ES:EDI"或"ES:DI"的内存地址中去
        ; 以STOSD为例子：
        ; DF=0:   eax->es:edi     edi+4  
        ; DF=1:   eax->es:edi     edi-4  
        stosd

        add    eax, 4096      ; 每个PTE是4k，所以地址+4k
        loop   .1

        ; 再初始化所有PTE (1k个页表，每个表里面有1k个PTE，每个PTE=4B，所以是4M)
        mov    ax, SelectorPageTbl    ; 该段首地址位PageTblBase
        mov    es, ax

        mov    ecx, 1024 * 1024       ; 1k * 1k

        xor    edi, edi
        xor    eax, eax

        ; 这里是指定每一个页的首地址
        ; 第一个页的首地址是0x00000000，下面没有将0x00000000写上，看起来像是没有地址一样。
        ; TODO: 修改地址，不使用0x0000000作为页的起始地址，挪动一两个字节看看
        ; 测试结果，修改地址也起不到预想的作用，现在想不明白，等pmtest8弄完以后再回头看看
        mov    eax, PageTestBase | PG_P | PG_USU | PG_RWW

.2:
        stosd
        add    eax, 4096      ; 每个页是4k，所以地址+4k
        loop   .2

        ; 准备开启分页
        ; 首先，让cr3指向PDE的首地址
        mov    eax, PageDirBase
        mov    cr3, eax

        ; 设置cr0的PG位，开启分页
        mov    eax, cr0
        or     eax, 80000000h
        mov    cr0, eax

        ; zf: 这个jmp的作用是什么？去掉是否可以?
        ; 测试结果：去掉没有问题。。。。先忽略吧。。。。
        ;jmp    short .3

.3
        ; zf: 这个nop的作用？？？
        ; 测试结果：去掉没有问题。。。。先忽略吧。。。。
        ;nop

        ret
; SetupPaging 结束---------------------------------------------------------

SegCode32Len    equ    ($ - LABEL_SEG_CODE32)

; END of [SECTION .s32]

; ===================   16位代码段   =======================

; 16 位代码段. 由 32 位代码段跳入, 跳出后到实模式
; 不能从32位保护模式直接跳回实模式，需要先从32位代码段跳到16位代码段，设置寄存器，再跳回实模式

[SECTION .s16code]
ALIGN    32
[BITS    16]

LABEL_SEG_CODE16:
    ; 先将保护模式中使用的寄存器都使用SelectorNormal设置一下
    ; 好像是让高速寄存器含有合适的段界限和属性
    mov    ax, SelectorNormal
    mov    ds, ax
    mov    es, ax
    mov    fs, ax
    mov    gs, ax
    mov    ss, ax
    
    mov    eax, cr0

    ; zf: 调试的时候，发现无法回到dos下面
    ; 在将pe为清零的时候，出错提示：
    ; [121089125] [0x0000000161aa] 0028:00000012 (unk. ctxt): mov cr0, eax
    ; check_CR0(0xe0000010): attempt to set CR0.PG with CR0.PE cleared 
    ;
    ; 原因：mov cr0，ax这句，尝试在PG=0的情况下，设置PE，显然是失败的。
    ; 因此，书中的代码实际上是不对的，必须同时关闭分页机制和分段机制，才能跳回到dos
    and    eax, 7ffffffeh     ; PE=0, PG=0关闭分页,进入实模式 
    
    mov    cr0, eax

LABEL_GO_BACK_TO_REAL:
    jmp    0:LABEL_REAL_ENTRY    ; 这里是跳回实模式，其实就是 jmp cs:offset
                                 ; 不过cs设置成0了，但是在97行代码处，将该处的0填充成了实模式下cs的值。


Code16Len    equ    ($ - LABEL_SEG_CODE16)

; END of [SECTION .s16code]