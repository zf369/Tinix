; ==========================================
; pmtest8.asm
; 分页机制终章，切换分页
; ==========================================

%include "pm.inc"  ; 常量, 宏, 以及一些说明

PageDirBase0    equ    200000h ; PDE的开始地址：0x200000h(2M)
PageTblBase0    equ    201000h ; PTE的开始地址：0x201000h(2M + 4k)
PageDirBase1    equ    210000h ; PDE的开始地址：0x200000h(2M + 64k)
PageTblBase1    equ    211000h ; PTE的开始地址：0x201000h(2M + 64k + 4k)

PageTestBase    equ    0FFFh ; 测试修改页的起始地址

LinearDemoAddr      equ    00401000h
ProcFooAddr         equ    00401000h
ProcBarAddr         equ    00501000h
ProcPagingDemoAddr  equ    00301000h

org    0100h
       jmp    LABEL_BEGIN     ; 接下来的是gdt数据部分，不是代码，必须要跳过去
       ; "jmp LABEL_BEGIN"不改变CS，所以在没有长跳转之前CS一直是0100H。后面令DS=CS;
       ; 后面的"add eax, LABEL_GDT"中"LABEL_GDT"是相对于DS（0x0100H）的偏移，得到绝对地址。
       ; "add eax,LABEL_SEG_CODE32"中也一样，所以可以确定，nasm中所有的LABEL的都是相对于当前DS的偏移。

       ; label 本身是按照距离程序首部开始计算的。而且16位的汇编程序编译成bin文件之后，汇编程序的组织结构和最终内存结构几乎一样（16位汇编程序的段首地址是16的整数倍，段末尾不够长度的补0）


; ===================   GDT   =======================

[SECTION .gdt]
; GDT
;                                     段基址                段界限    属性
LABEL_GDT:            Descriptor          0,                   0,    0         ; 空描述符
LABEL_DESC_NORMAL:	  Descriptor	      0,              0ffffh, DA_DRW	   ; Normal描述符
LABEL_DESC_FLAT_C:    Descriptor          0,             0fffffh, DA_CR | DA_32 | DA_LIMIT_4K ; 4G
LABEL_DESC_FLAT_RW:   Descriptor          0,             0fffffh, DA_DRW | DA_LIMIT_4K ; 4G
LABEL_DESC_CODE32:    Descriptor          0,    SegCode32Len - 1, DA_CR + DA_32 ; 非一致代码段, 32位代码段
LABEL_DESC_CODE16:    Descriptor          0,              0ffffh, DA_C          ; 非一致代码段, 16位代码段
LABEL_DESC_DATA:	  Descriptor	      0,	     DataLen - 1, DA_DRW        ; Data
LABEL_DESC_STACK:	  Descriptor	      0,          TopOfStack, DA_DRWA + DA_32	; Stack, 32 位
LABEL_DESC_VIDEO:     Descriptor    0B8000h,              0ffffh, DA_DRW       ; 数据段，显存首地址

; GDT END

GdtLen        equ    $ - LABEL_GDT    ; GDT长度
GdtPtr        dw     GdtLen - 1       ; GDT界限=GdtLen-1？段界限=段内的最大偏移，从0开始。
              dd     0                ; GDT基地址，这个是暂时填0，后面ds确定了以后再填充

; GDT 选择子
SelectorNormal		equ	LABEL_DESC_NORMAL	   - LABEL_GDT
SelectorFlatC       equ LABEL_DESC_FLAT_C      - LABEL_GDT
SelectorFlatRW      equ LABEL_DESC_FLAT_RW     - LABEL_GDT
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

; ---------------- 实模式下使用以下符号:

; 字符串
_szPMMessage:     db  "In Protect Mode now. ^-^", 0Ah, 0Ah, 0  ; 进入保护模式以后显示该字符串
_szMemChkTitle:   db  "BaseAddrL BaseAddrH LengthLow LengthHigh   Type", 0Ah, 0
_szRAMSize        db  "RAM size:", 0
_szReturn         db  0Ah, 0

; 变量
_wSPValueInRealMode    dw    0
_dwMCRNumber           dd    0    ; Memory Check Result
_dwDispPos:            dd    (80 * 6 + 0) * 2   ; 屏幕第 6 行, 第 0 列。
_dwMemSize             dd    0
_ARDStruct:         ; Address Range Descriptor Structure
    _dwBaseAddrLow:    dd    0
    _dwBaseAddrHigh:   dd    0
    _dwLengthLow:      dd    0
    _dwLengthHigh:     dd    0
    _dwType:           dd    0

_PageTableNumber       dd    0

_MemChkBuf:    times   256  db  0


; ---------------- 保护模式下使用以下符号:
; 因为程序是在实模式下编译的，上面的地址都是实模式下的地址，在保护模式下面，数据的地址是相对于段基址的offset。
; 比如：上面的"_szPMMessage"相当于那一行的"$"，"$"指向当前行相对于段基址(设为var)的偏移地址。即"$=var+msg_offset"
; "$$"指向当前section相对于段基址的偏移地址，即"$$=var+sec_offset"
; 所以，"szPMMessage = _szPMMessage-$$" = "szPMMessage = (var+msg_offset) - (var+sec_offset)"
; 最后，"szPMMessage = msg_offset - sec_offset"，最后寻址的时候加上正确的段基址即可。

szPMMessage     equ     _szPMMessage - $$
szMemChkTitle   equ     _szMemChkTitle  - $$
szRAMSize       equ     _szRAMSize   - $$
szReturn        equ     _szReturn    - $$
dwDispPos       equ     _dwDispPos   - $$
dwMemSize       equ     _dwMemSize   - $$
dwMCRNumber     equ     _dwMCRNumber - $$
ARDStruct       equ     _ARDStruct   - $$
    dwBaseAddrLow   equ _dwBaseAddrLow  - $$
    dwBaseAddrHigh  equ _dwBaseAddrHigh - $$
    dwLengthLow     equ _dwLengthLow    - $$
    dwLengthHigh    equ _dwLengthHigh   - $$
    dwType          equ _dwType     - $$
MemChkBuf       equ     _MemChkBuf  - $$

PageTableNumber equ     _PageTableNumber- $$


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
        mov [_wSPValueInRealMode], sp    ; 实模式下: label=从文件最开始算起的offset

        ; 通过15h中断，得到内存数
        mov    ebx, 0            ; ebx中存放后续值，第一次调用给0
        mov    di, _MemChkBuf    ; di：的是中断返回ARDS结果的存放地址

.loop:
        mov    eax, 0E820h       ; eax存放0e820h固定值
        mov    ecx, 20           ; 返回的ARDS就是20字节
        mov    edx, 0534D4150h   ; "SMAP"
        int    15h

        jc     LABEL_MEM_CHK_FAIL ; JC=Jump if Carry 当运算产生进位标志时，即CF=1时，跳转到目标程序处。
                                  ; CF=0 表示没有错误

        add    di, 20            ; 移动20字节，因为刚获得了20字节返回结果
        inc    dword [_dwMCRNumber]

        cmp    ebx, 0            ; 如果ebx=0 && CF=0，说明当前是最后一个内存地址描述符

        jne    .loop

        jmp    LABEL_MEM_CHK_OK  ; 获得了所有内存描述符，数目放到了_dwMCRNumber中，数据在_MemChkBuf中

LABEL_MEM_CHK_FAIL:
        mov    dword [_dwMCRNumber], 0

LABEL_MEM_CHK_OK:
        ; 获取内存完毕

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

        ; 将保存在_wSPValueInRealMode处的sp恢复
        mov sp, [_wSPValueInRealMode]

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
        mov    es, ax          ; 数据段选择子->ds，保护模式的段地址都是Selector

        mov    ax, SelectorVideo
        mov    gs, ax          ; 视频段选择子(目的)

        mov    ax, SelectorStack
        mov    ss, ax          ; 堆栈段选择子

        mov    esp, TopOfStack ; esp 指向栈底



        ; 下面显示一个字符串PMMessage
        push   szPMMessage
        call   DispStr
        add    esp, 4

        ; 显示szMemChkTitle
        push   szMemChkTitle
        call   DispStr
        add    esp, 4

        ; 显示内存信息
        call   DispMemSize

        ; 演示改变页目录的效果
        call   PagingDemo

        ; 到此停止，跳到16位代码段，准备回到实模式
        jmp SelectorCode16:0

; ------------------------------------------------------------------------
; SetupPaging: 启动分页机制
;
;     为了简化处理，所有线性地址对应相等的物理地址，即F(0x12345678) = 0x12345678
;     假设线性地址0x12345678，经过分页管理机制转换以后，对应的物理地址正好也是0x12345678
; ------------------------------------------------------------------------

SetupPaging:
        
        ; 根据内存大小计算应该初始化多少PDE以及多少页表
        xor    edx, edx

        mov    eax, [dwMemSize]
        mov    ebx, 400000h        ; 400000 = 4M = 4096 * 1024, 一个页表对应的内存大小

        div    ebx

        ; 打印商出来看看
        ;push    eax
        ;call    DispInt
        ;pop     eax
        ; 打印余数出来看看
        ;push    edx
        ;call    DispInt
        ;pop     edx

        mov    ecx, eax            ; 商在eax中，挪到ecx中

        test   edx, edx
        
        jz     .no_remainder
        inc    ecx                 ; 如果余数不为0，增加一个页表

.no_remainder
        mov    [PageTableNumber], ecx ; 将页表数目存入到PageTableNumber中

        ; 为简化处理, 所有线性地址对应相等的物理地址. 并且不考虑内存空洞.

        ; 初始化PDE
        mov    ax, SelectorFlatRW    ; 该段首地址=0
        mov    es, ax
        
        mov    edi, PageDirBase0     ; 偏移地址为PageDirBase0

        xor    eax, eax

        ; PageTblBase是TBL的入口地址，32位，但是页表项是4k对齐，所以低20位必然位0
        ; 因此低20位可以用来标识该页的一些基本属性，后面3个属性是存在、可读写、用户表。
        mov    eax, PageTblBase0 | PG_P | PG_USU | PG_RWW

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
        mov    eax, [PageTableNumber]  ; 获取页表个数
        mov    ebx, 1024
        mul    ebx

        mov    ecx, eax            ; PTE个数 = PDE个数 * 1024

        mov    edi, PageTblBase0   ; ; 偏移地址为PageTblBase0

        xor    eax, eax

        ; 这里是指定每一个页的首地址
        ; 第一个页的首地址是0x00000000，下面没有将0x00000000写上，看起来像是没有地址一样。
        ; zf: 修改地址，不使用0x0000000作为页的起始地址，挪动一两个字节看看
        ; 测试结果，修改地址也起不到预想的作用，因为4k对齐的问题，所以修改的地址必须大于4k
        mov    eax, PageTestBase | PG_P | PG_USU | PG_RWW

.2:
        stosd
        add    eax, 4096      ; 每个页是4k，所以地址+4k
        loop   .2

        ; 准备开启分页
        ; 首先，让cr3指向PDE的首地址
        mov    eax, PageDirBase0
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



; ------------------------------------------------------------------------
; PagingDemo: 测试分页机制
;
;     测试切换分页
; ------------------------------------------------------------------------
PagingDemo:
    
    mov    ax, cs     ; cs里面现在存的是SelectorCode32, 将SelectorCode32放入ds
    mov    ds, ax     ; 因为要复制的函数PagingDemoProc、foo、bar都在这个32位代码段中

    mov    ax, SelectorFlatRW
    mov    es, ax     ; SelectorFlatRW是要复制的目标段的选择子，这个段是4G可读写的段

    ; 复制函数foo到ProcFooAddr(0x00401000h)位置处
    push   LenFoo
    push   OffsetFoo
    push   ProcFooAddr
    call   MemCpy
    add    esp, 12

    ; 复制函数bar到ProcBarAddr(0x00501000h)位置处
    push   LenBar
    push   OffsetBar
    push   ProcBarAddr
    call   MemCpy
    add    esp, 12

    ; 复制函数PagingDemoProc到ProcPagingDemoAddr(0x00301000h)位置处
    push   LenPagingDemoAll
    push   OffsetPagingDemoProc
    push   ProcPagingDemoAddr
    call   MemCpy
    add    esp, 12

    mov    ax, SelectorData
    mov    ds, ax
    mov    es, ax

    call   SetupPaging    ; 启动分页

    ; 打印cs寄存器进行测试
    ;xor     eax, eax
    ;mov     ax, cs
    ;push    eax
    ;call    DispInt
    ;pop     eax

    ; zf: 测试一下直接call foo和bar函数的地址，不用调用PagingDemoProc函数的区别
    ; 测试结果：可以直接call，但是需要将foo的返回改成retf
    call   SelectorFlatC:ProcPagingDemoAddr    ; 这里SelectorFlatC这个段基址=0，所以起作用的就是偏移地址

    call   PSwitch        ; 切换页目录，改变地址映射关系
    
    call   SelectorFlatC:ProcPagingDemoAddr

    ret

; PagingDemo 结束---------------------------------------------------------


; ------------------------------------------------------------------------
; PSwitch: 切换页表
; ------------------------------------------------------------------------
PSwitch:
    
    ; 初始化PDE
    mov    ax, SelectorFlatRW    ; 该段首地址=0
    mov    es, ax
    
    mov    edi, PageDirBase1     ; 偏移地址为PageDirBase1

    xor    eax, eax

    ; PageTblBase是TBL的入口地址，32位，但是页表项是4k对齐，所以低20位必然位0
    ; 因此低20位可以用来标识该页的一些基本属性，后面3个属性是存在、可读写、用户表。
    mov    eax, PageTblBase1 | PG_P | PG_USU | PG_RWW

    mov    ecx, [PageTableNumber]

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
    mov    eax, [PageTableNumber]  ; 获取页表个数
    mov    ebx, 1024
    mul    ebx

    mov    ecx, eax            ; PTE个数 = PDE个数 * 1024

    mov    edi, PageTblBase1   ; 偏移地址为PageTblBase1

    xor    eax, eax

    ; 这里是指定每一个页的首地址
    mov    eax, PageTestBase | PG_P | PG_USU | PG_RWW

.2:
    stosd
    add    eax, 4096      ; 每个页是4k，所以地址+4k
    loop   .2

    ; 在此假设内存是大于 8M 的

    ; 0x00401000,转化为2进制为：0000，0000，0100，0000，0001，0000，0000，0000
    mov    eax, LinearDemoAddr
    shr    eax, 22             ; eax变为0x00000001
    mov    ebx, 4096
    mul    ebx                 ; eax变为0x00001000

    mov    ecx, eax            ; ecx=0x00001000

    ; 0x00401000,转化为2进制为：0000，0000，0100，0000，0001，0000，0000，0000
    mov    eax, LinearDemoAddr            
    shr    eax, 12                        ; eax=0x00000401
    and    eax, 03FFh                     ; 1111111111b (10 bits)  eax=0x00000001
    mov    ebx, 4                         ; ebx=0x00000004
    mul    ebx                            ; eax=0x00000004

    add    eax, ecx                       ; eax=0x00001004

    add    eax, PageTblBase1              ; add eax,0x00211000,eax变为0x00212004

    ; [es:eax]指向SelectorFlatRW的0x00212004,这句肯定把原来函数地址变了。
    mov    dword [es:eax], ProcBarAddr | PG_P | PG_USU | PG_RWW


    ; 首先，让cr3指向PDE1的首地址
    mov    eax, PageDirBase1
    mov    cr3, eax

    ; zf: 这个jmp的作用是什么？去掉是否可以?
    ; 测试结果：去掉没有问题。。。。先忽略吧。。。。
    ;jmp    short .3

.3
    ; zf: 这个nop的作用？？？
    ; 测试结果：去掉没有问题。。。。先忽略吧。。。。
    ;nop

    ret

; PSwitch 结束---------------------------------------------------------


; ------------------------------------------------------------------------
; PagingDemoProc: 调用LinearDemoAddr地址的函数，LinearAddrDemo由页表查询
; ------------------------------------------------------------------------
PagingDemoProc:
OffsetPagingDemoProc    equ    PagingDemoProc - $$
    
    ; zf：测试一下直接call，不使用eax会有什么区别???
    ; 测试结果：call SelectorFlatC:LinearDemoAddr可以执行，call LinearDemoAddr不行
    ; 注意：这里LinearDemoAddr是一个绝对地址，而上面的比如call PSwitch中的PSwitch是label
    ; call  Label   -----  IP=IP+16位偏移量(16位位移由编译程序在编译时算出)
    ; call  imm     -----  IP=IP+imm(是一个相对当前位置的偏移量，和label的区别就是指定的偏移量)
    ; call  reg     -----  IP=reg

    ; call reg 是直接跳转到寄存器值所指的偏移位置（这里的偏移是相对于段，也就是说，对段内而言，这种方式直接跳转到一个绝对地址，而不是与当前位置的偏移） 
    mov    eax, LinearDemoAddr
    call   eax                    

    ; call imm 是一个相对当前位置的偏移量
    ;call    LinearDemoAddr

    ; 这是可以成功的，但是必须retf返回
    ; zf: 测试下面这种调用方式是否触发分页
    ; 测试结果：可以触发分页
    ;call    SelectorFlatC:LinearDemoAddr

    retf              ; retf 返回是因为调用的时候使用的是"call selector:offset"的方式

LenPagingDemoAll    equ    $ - PagingDemoProc
; PSwitch 结束---------------------------------------------------------


; ------------------------------------------------------------------------
; foo: 打印Foo
; ------------------------------------------------------------------------
foo:
OffsetFoo    equ    foo - $$
    
    mov    ah, 0Ch        ; 0000: 黑底    1100: 红字

    mov    al, 'F'
    mov    [gs:((80*17 + 0) * 2)], ax    ; 屏幕第 17 行, 第 0 列。

    mov    al, 'o'
    mov    [gs:((80*17 + 1) * 2)], ax    ; 屏幕第 17 行, 第 1 列。
    mov    [gs:((80*17 + 2) * 2)], ax    ; 屏幕第 17 行, 第 2 列。

    ret

LenFoo    equ    $ - foo
; foo 结束---------------------------------------------------------


; ------------------------------------------------------------------------
; bar: 打印Bar
; ------------------------------------------------------------------------
bar:
OffsetBar    equ    bar - $$
    
    mov    ah, 0Ch        ; 0000: 黑底    1100: 红字

    mov    al, 'B'
    mov    [gs:((80*18 + 0) * 2)], ax    ; 屏幕第 18 行, 第 0 列。

    mov    al, 'a'
    mov    [gs:((80*18 + 1) * 2)], ax    ; 屏幕第 18 行, 第 1 列。

    mov    al, 'r'
    mov    [gs:((80*18 + 2) * 2)], ax    ; 屏幕第 18 行, 第 2 列。
    
    ret

LenBar    equ    $ - bar
; bar 结束---------------------------------------------------------



; ------------------------------------------------------------------------
; DispMemSize: 显示之前15h中断获得的所有内存信息
; ------------------------------------------------------------------------
DispMemSize:
        
        push    esi
        push    edi
        push    ecx

        mov     esi, MemChkBuf
        mov     ecx, [dwMCRNumber]  ; for(int i=0;i<[MCRNumber];i++) // 每次得到一个ARDS

.loop:                              ; {

        mov     edx, 5              ;    for (int j=0; j<5; j++) // 每次得到一个ARDS中的成员，共5个成员
        mov     edi, ARDStruct      ;    {// BaseAddrLow，BaseAddrHigh，LengthLow，LengthHigh，Type

.1:

        push    dword [esi]
        call    DispInt             ;       DispInt(MemChkBuf[j*4]); // 显示一个成员
        pop     eax

        stosd                       ;       ARDStruct[j*4] = MemChkBuf[j*4];

        add     esi, 4
        dec     edx
        cmp     edx, 0
        jnz     .1                  ;     }

        call    DispReturn          ;     printf("\n");

                                    ;     // AddressRangeMemory=1, AddressRangeReserved=2
        cmp     dword [dwType], 1   ;     if(Type==AddressRangeMemory)
        jne     .2                  ;     {

        mov     eax, [dwBaseAddrLow]
        add     eax, [dwLengthLow]
        cmp     eax, [dwMemSize]    ;        if(BaseAddrLow + LengthLow > MemSize)

        jb      .2

        mov     [dwMemSize], eax    ;        MemSize = BaseAddrLow + LengthLow;
                                    ;      }

.2:
        loop    .loop               ; }

        call    DispReturn          ; printf("\n");

        push    szRAMSize           
        call    DispStr             ; printf("RAM size:");
        add     esp, 4

        push    dword [dwMemSize]
        call    DispInt
        add     esp, 4

        pop     ecx
        pop     edi
        pop     esi

        ret

; DispMemSize 结束---------------------------------------------------------

%include    "lib.inc"    ; 引入库函数，在哪一个段中include，就相当于在那块插入了代码

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