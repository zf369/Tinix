; ==========================================
; loader.asm
; 简单的Loader，在软盘中查找名为'kernel.bin'的文件，将它放入到内存中
; ==========================================

;%define    _LOADER_DEBUG_

; 需要booter将它复制到内存0100h处，放在这个地址的好处是，也可以编译成com文件进行调试
org    0100h    
    
    ; 跳转到代码处执行
    jmp    LABEL_START

; ----------- 包含一些预定义的文件 -----------
%include    "fat12hdr.inc"    ; FAT12 磁盘的头, 包含它是因为下面用到了磁盘的一些信息
%include    "load.inc"        ; 段地址和偏移地址
%include    "pm.inc"          ; 保护模式的一些预定义
; ---------------------------------------------------------------------

; ===================   GDT   =======================

; GDT
;                                     段基址                段界限    属性
LABEL_GDT:            Descriptor          0,                   0,    0         ; 空描述符
LABEL_DESC_FLAT_C:    Descriptor          0,             0fffffh, DA_CR | DA_32 | DA_LIMIT_4K ; 4G
LABEL_DESC_FLAT_RW:   Descriptor          0,             0fffffh, DA_DRW | DA_32 | DA_LIMIT_4K ; 4G
LABEL_DESC_VIDEO:     Descriptor    0B8000h,              0ffffh, DA_DRW | DA_DPL3 ; 显存首地址
; Stack, 32 位数据段，

; GDT END

GdtLen        equ    $ - LABEL_GDT    ; GDT长度
GdtPtr        dw     GdtLen - 1       ; GDT界限=GdtLen-1？段界限=段内的最大偏移，从0开始。
              dd     BaseOfLoaderPhyAddr + LABEL_GDT ; GDT基地址，loader起段地址已确定

; GDT 选择子
SelectorFlatC       equ LABEL_DESC_FLAT_C      - LABEL_GDT
SelectorFlatRW      equ LABEL_DESC_FLAT_RW     - LABEL_GDT
SelectorVideo       equ LABEL_DESC_VIDEO       - LABEL_GDT + SA_RPL3

; ===================   GDT END   =======================


;================================================================================================
BaseOfStack        equ    0100h
;================================================================================================


;================================================================================================
; <--- 从这里开始 *************
LABEL_START:
    mov    ax, cs
    mov    ds, ax
    mov    es, ax

    mov    ss, ax
    mov    sp, BaseOfStack

    mov    dh, 0       ; "Loading  "
    call   DispStrRealMode

    ; 通过15h中断，得到内存数
    mov    ebx, 0            ; ebx中存放后续值，第一次调用给0
    mov    di, _MemChkBuf    ; di：的是中断返回ARDS结果的存放地址

.MemChkLoop:
    mov    eax, 0E820h       ; eax存放0e820h固定值
    mov    ecx, 20           ; 返回的ARDS就是20字节
    mov    edx, 0534D4150h   ; "SMAP"
    int    15h

    jc     .MemChkFail ; JC=Jump if Carry 当运算产生进位标志时，即CF=1时，跳转到目标程序处。
                       ; CF=0 表示没有错误

    add    di, 20            ; 移动20字节，因为刚获得了20字节返回结果
    inc    dword [_dwMCRNumber]

    cmp    ebx, 0            ; 如果ebx=0 && CF=0，说明当前是最后一个内存地址描述符

    jne    .MemChkLoop

    jmp    .MemChkOK  ; 获得了所有内存描述符，数目放到了_dwMCRNumber中，数据在_MemChkBuf中

.MemChkFail:
    mov    dword [_dwMCRNumber], 0

.MemChkOK:
    ; 获取内存完毕

    ; INT13中断详解 功能00H 
	; 功能描述：磁盘系统复位 入口参数：AH＝00H 
	; DL＝驱动器，00H~7FH：软盘；80H~0FFH：硬盘 
	; 出口参数：CF＝0——操作成功，AH＝00H，否则，AH＝状态代码，参见功能号01H中的说明 
    xor    ah, ah    ; ┓
    xor    dl, dl    ; ┣ 软驱复位
    int    13h       ; ┛
    
    ; ----------- 下面是在软盘的根目录查找kernel.bin文件
    mov    word [wSectorNo], SectorNoOfRootDirectory ; wSectorNo=19，根目录开始的扇区

LABEL_SEARCH_IN_ROOT_DIR_BEGIN:

    cmp    word [wRootDirSizeForLoop], 0 ; ┓ 判断根目录区是不是已经读完
    jz     LABEL_NO_KERNELBIN            ; ┛ 

    dec    word [wRootDirSizeForLoop]    ; wRootDirSizeForLoop--

    mov    ax, BaseOfKernelFile
    mov    es, ax                 ; es <- BaseOfKernelFile
    mov    bx, OffsetOfKernelFile ; bx <- OffsetOfKernelFile 于是：es:bx = BaseOfLoader:OffsetOfKernelFile

    mov    ax, [wSectorNo]    ; ax <- 根目录区中的某个扇区号
    mov    cl, 1
    call   ReadSector         ; 将根目录中的当前扇区读取到es:bx处

    mov    si, KernelFileName     ; ds:si -> "KERNEL  BIN"
    mov    di, OffsetOfKernelFile ; di = OffsetOfKernelFile  
                                  ; es:di BaseOfKernelFile:00 = BaseOfKernelFile*10h+00
                                  ; 文件名在每个目录条目的最开始，所以es:di指的就是第一个条目的文件名

    cld                       ; cld使DF 复位，即是让DF=0，std使DF置位，即DF=1.

    mov    dx, 10h            ; 因为一个扇区最多有512/32=16个根目录

LABEL_SEARCH_FOR_KERNELBIN:
    cmp    dx, 0                              ; ┓循环次数控制,如果已经读完了一个扇区,
    jz     LABEL_GOTO_NEXT_SECTOR_IN_ROOT_DIR ; ┛就跳到下一个

    dec    dx                  ; dx--

    mov    cx, 11              ; "KERNEL  BIN" 11字节

LABEL_CMP_FILENAME:

	cmp    cx, 0
	jz     LABEL_FILENAME_FOUND ; 11个字符都相等, 表示找到

	dec    cx                   ; cx--

	lodsb                       ; ds:si -> al

	cmp    al, byte [es:di]     ; 比较当前字符是否和di指向的字符相等

	jz     LABEL_GO_ON

	jmp    LABEL_DIFFERENT      ; 字符不相等，表面当前DirectoryEntry不是kernel.bin

LABEL_GO_ON:
    inc    di                   ; di++ 准备比较下一个字符
    jmp    LABEL_CMP_FILENAME   ; 继续比较

LABEL_DIFFERENT:
    and    di, 0FFE0h           ; ┓	di &= E0 为了让它指向本条目开头，每个条目是32字节对齐，所以低5位肯定=0
    add    di, 20h              ; ┛ di += 20h  下一个目录条目
    mov    si, KernelFileName   ; si重新指向"LOADER  BIN"字符串

    jmp    LABEL_SEARCH_FOR_KERNELBIN ; 接着比较下一个文件

LABEL_GOTO_NEXT_SECTOR_IN_ROOT_DIR:
    add    word [wSectorNo], 1             ; 读取的根目录区的扇区号+1
    jmp    LABEL_SEARCH_IN_ROOT_DIR_BEGIN  ; 继续查找新的扇区里面的文件是否有loader.bin

LABEL_NO_KERNELBIN:
    mov    dh, 2              ; "No KERNEL."的序号
    call   DispStrRealMode

%ifdef    _LOADER_DEBUG_
    ; INT 21是计算机中断的一种，不同的AH值表示不同的中断功能。4CH号功能——带返回码结束程序。AL=返回码
    mov    ax, 4c00h    ; ┓4CH号功能——带返回码结束程序。AL=返回码
    int    21h          ; ┛没有找到 kernel.bin, 回到DOS
%else
    jmp    $            ; 没有找到kernel.bin，停在这里
%endif

LABEL_FILENAME_FOUND:         ; 找到kernel.bin以后jmp到这里继续执行
    
    ; 先查找kernel.bin文件的条目中存储的起始簇号(即起始扇区号)
    and    di, 0FFE0h           ; di &= E0 为了让它指向本条目开头，每个条目是32字节对齐，所以低5位肯定=0

    push   eax
    mov    eax, [es:(di+01Ch)]        ; di += 1Ch  文件大小
    mov    dword [dwKernelSize], eax ; 保存 KERNEL.BIN 文件大小
    pop    eax

    add    di, 01Ah             ; di += 1Ah  起始簇号
    mov    cx, word [es:di]     ; 将簇号放入cx
    push   cx                   ; 保存簇号，后面还要用

    mov    ax, RootDirSectors   ; ax = 14 (即根目录区总扇区)
    add    cx, ax               ; cx = cx + 14
    add    cx, DeltaSectorNo    ; cx = 17 + 14 + 起始簇号，实际上是: cx = 19 + 14 + (簇号-2)
                                ; cx 里面变成 LOADER.BIN 的起始扇区号 (从 0 开始数的序号)

    mov    ax, BaseOfKernelFile
    mov    es, ax                 ; es <- BaseOfKernelFile
    mov    bx, OffsetOfKernelFile ; bx <- OffsetOfKernelFile  
                                  ; es:bx=BaseOfKernelFile:OffsetOfKernelFile
    
    mov    ax, cx               ; ax = kernel.bin起始扇区号

LABEL_GOON_LOADING_FILE:
    
    push   ax         ; ┓
    push   bx         ; ┃
                      ; ┃
    mov    ah, 0Eh    ; ┃  AH=0E: 显示字符(光标前移) AL=字符  BL=前景色
    mov    al, '.'    ; ┃  每读一个扇区就在 "Booting  " 后面打一个点, 形成这样的效果:
    mov    bl, 0Fh    ; ┃  Booting ......
    int    10h        ; ┃
                      ; ┃
    pop    bx         ; ┃
    pop    ax         ; ┛

    ; 根据ax中的扇区号去根目录中读取一个扇区到 es:bx 处
    mov    cl, 1
    call   ReadSector

    ; 读取完毕以后，在FAT中查找该目录条目(FATEntry)
    pop    ax         ; 取出此 Sector 在 FAT 中的序号
    call   GetFATEntry

    ; 查看loader.bin是否还有下一个扇区需要读取
    cmp    ax, 0FFFh 

    ; loader.bin已经读取完毕，跳转执行loader
    jz     LABEL_FILE_LOADED

    ; 保存下一个需要读取的扇区的起始簇号
    push   ax

    ; 计算起始扇区的扇区号: 扇区号 = 19 + 14 + (簇号-2)
    mov    dx, RootDirSectors
    add    ax, dx
    add    ax, DeltaSectorNo

    ; 已经读取了一个扇区，bx向后移动一个扇区的长度(512B)
    add    bx, [BPB_BytsPerSec]

    ; 继续读取下一个扇区
    jmp    LABEL_GOON_LOADING_FILE

LABEL_FILE_LOADED:

    call   KillMotor          ; 关闭软驱马达

    ; 显示Ready字符串
    mov    dh, 1              ; "Ready.   "的序号
    call   DispStrRealMode

; ***************************************************************************
; >>>>>>>>>>>>>>>>>>>>>>>> 下面准备跳入保护模式 <<<<<<<<<<<<<<<<<<<<<<<<

    ; 加载 GDTR
    lgdt   [GdtPtr]

    ; 关中断
    cli

    ; 打开地址线A20
    in     al, 92h       ; in al，92h 表示从92h号端口读入一个字节
    or     al, 00000010b
    out    92h, al       ; out 92h，al 表示向92h号端口写入一个字节

    ; 准备切换到保护模式
    mov    eax, cr0
    or     eax, 1
    mov    cr0, eax


    ; 跳转到32位代码段执行
    jmp    dword SelectorFlatC:(BaseOfLoaderPhyAddr + LABEL_PM_START)

    jmp    $

; ***************************************************************************


;============================================================================
;变量
;----------------------------------------------------------------------------
wRootDirSizeForLoop    dw    RootDirSectors    ; 根目录占用的扇区数，在循环中会递减到0
wSectorNo              dw    0                 ; 要读取的扇区号
bOdd                   db    0                 ; 奇偶标识位

dwKernelSize    	   dd    0                 ; KERNEL.BIN 文件大小
;============================================================================

;============================================================================
;字符串
;----------------------------------------------------------------------------
; kernel.bin文件名(注意，在目录区文件名都是大写，文件名8字节，不足8字节补充空格，后缀名3字节)
KernelFileName         db    "KERNEL  BIN", 0  

; 为简化代码, 下面每个字符串的长度均为 MessageLength
MessageLength          equ    9

LoadMessage            db     "Loading  "    ; 9字节, 不够则用空格补齐. 序号 0
Message1               db     "Ready.   "    ; 9字节, 不够则用空格补齐. 序号 1
Message2               db     "No KERNEL"    ; 9字节, 不够则用空格补齐. 序号 2
;============================================================================



;----------------------------------------------------------------------------
; 函数名: DispStrRealMode
;
; 运行环境:
;   实模式（保护模式下显示字符串由函数 DispStr 完成）
;
; 作用:
;	显示一个字符串, 函数开始时 dh 中应该是字符串序号(0-based)
;----------------------------------------------------------------------------
DispStrRealMode:
    mov    ax, MessageLength  ; 将MessageLength赋值给ax
    mul    dh                 ; ax = dh * MessageLength，即数组的offset

    add    ax, LoadMessage    ; ax = LoadMessage + offset，即数组对应的元素地址

    mov    bp, ax             ; ┓
    mov    ax, ds             ; ┣ int10h中断，es:bp是显示字符串的地址
    mov    es, ax             ; ┛

    mov    cx, MessageLength  ; cx计数寄存器, int10h中断中cx=len

    ; ah= 13表示在Teletype模式下显示字符串（Teletype模式？没搞懂）
	; al= 01表示字符串中只含显示字符，其显示属性在bl中
	; 显示后，光标位置改变
	mov    ax, 01301h

	; bx称为基址寄存器
	; bh = 0表示页号为0
	; bl = 0ch，当al = 00h或01h时，使用bl属性
	; bl = 0ch表示黑底红字, 颜色可见《linux》p25
	mov    bx, 0007h

	; dx数据寄存器, 
	; 在进行乘、除运算时，它可作为默认的操作数参与运算，
	; 也可用于存放I/O的端口地址。
	; 在int10h中断中dh表示字符串要显示的行，
	mov    dh, 1 		; dh表示字符串在屏幕的多少行显示
	mov    dl, 3        ; dl表示字符串在屏幕的多少列显示

	int    10h    ; 10h号中断

	ret           ; 返回

; DispStrRealMode 结束----------------------------------------------------------------



;----------------------------------------------------------------------------
; 函数名: ReadSector
; 作用:
;	从第 ax 个 Sector 开始, 将 cl 个 Sector 读入 es:bx 中
; -----------------------------------------------------------------------
	; 怎样由扇区号求扇区在磁盘中的位置 (扇区号 -> 柱面号, 起始扇区, 磁头号)
	; -----------------------------------------------------------------------
	; 设扇区号为 x
	;                          ┌ 柱面号 = y >> 1
	;       x           ┌ 商 y ┤
	; -------------- => ┤      └ 磁头号 = y & 1
	;  每磁道扇区数       │
	;                   └ 余 z => 起始扇区号 = z + 1
;----------------------------------------------------------------------------

ReadSector:

    push    bp

    mov     bp, sp
    sub     esp, 2            ; 辟出两个字节的堆栈区域保存要读的扇区数: byte [bp-2]

    mov     byte [bp-2], cl   ; 把要读的扇区数放在byte[bp-2]的堆栈空间

    push    bx                ; 保存bx，因为要用到bl作为除数，所以要先push保护起来

    mov     bl, [BPB_SecPerTrk] ; bl: 除数
    div     bl                  ; ax/bl: 商y在al中，余数z在ah中

    inc     ah                  ; z++ 相当于余数加1，得到柱面的开始扇区号
    mov     cl, ah              ; cl <- 起始扇区号

    mov     dh, al              ; dh <- y

    shr     al, 1               ; y >> 1 (其实是 y/BPB_NumHeads, 这里BPB_NumHeads=2)
    mov     ch, al              ; ch <- 柱面号

    and     dh, 1               ; dh & 1 = 磁头号

    pop     bx                  ; 恢复bx
    ; 至此, "柱面号, 起始扇区, 磁头号" 全部得到 ^^^^^^^^^^^^^^^^^^^^^^^^

    mov     dl, [BS_DrvNum]     ; 驱动器号 (0 表示 A 盘)

.GoOnReading:
    mov     ah, 2
    mov     al, byte [bp-2]

    ; 功能02H  功能描述：读扇区 
    ; 入口参数：AH＝02H AL＝扇区数 CH＝柱面 CL＝扇区 DH＝磁头 
    ; DL＝驱动器，00H~7FH：软盘；80H~0FFH：硬盘 
    ; ES:BX＝缓冲区的地址 
    ; 出口参数：CF＝0——操作成功，AH＝00H，AL＝传输的扇区数，否则，AH＝状态代码，参见功能号01H中的说明 
    int     13h

    jc      .GoOnReading        ; 如果读取错误 CF 会被置为 1, 这时就不停地读, 直到正确为止

    add     esp, 2

    pop     bp

    ret

; ReadSector 结束----------------------------------------------------------------

;----------------------------------------------------------------------------
; 函数名: GetFATEntry
; 作用:
;   找到序号为 ax 的 Sector 在 FAT 中的条目, 结果放在 ax 中
;   需要注意的是, 中间需要读 FAT 的扇区到 es:bx 处, 所以函数一开始保存了 es 和 bx
;----------------------------------------------------------------------------

GetFATEntry: 
    
    push    es
    push    bx
    push    ax

    mov     ax, BaseOfKernelFile ; ┓
    sub     ax, 0100h            ; ┣ 在 BaseOfKernelFile 前面留出4K(段基址，0100h还要乘上个10h)空间存放FAT
    mov     es, ax               ; ┛ 

    pop     ax

    mov     byte [bOdd], 0

    ; 下面是整个函数的难点所在，计算簇号在FAT表中所对应的FATENTRY相对于FAT首地址的偏移。
    ; 从书上可以得知，FAT12中每个FATENTRY是12位的。所以如下：
    ; 7654 | 3210(byte1)    7654|3210(byte2)    7654|3210(byte3)
    ; byte1和byte2的低4位表示一个Entry；根据Big-Endian，Entry内容为：3210(byte2)76543210(byte1)
    ; byte3和byte2的高4位表示一个Entry；根据Big-Endian，Entry内容为：76543210(byte3)7654(byte2)
    ; 所以这里存在一个奇偶数的问题，以字节为单位。以上为例，Entry0偏移为0，Entry1偏移为1，Entry2偏移为3。
    ; 以INT[“簇号”*1.5]的方式增加。这也就是为什么上面先乘3再除2来计算。
    ; 根据DIV指令规定，商保存在ax中，余数在dx中。所以此时ax就是FATENTRY在FAT中以字节为边界的偏移量。
    mov     bx, 3
    mul     bx                  ; ax = ax * 3

    mov     bx, 2
    div     bx                  ; ax / 2 ==> ax <- 商, dx <- 余数

    cmp     dx, 0               ; 判断是奇数还是偶数
    jz      LABEL_EVEN

    mov     byte [bOdd], 1      ; 奇数设置标志位

LABEL_EVEN:
    ; ax 是FATEntry在FAT中的偏移量. 下面计算FATEntry在哪个扇区中(FAT占用不止一个扇区)
    xor     dx, dx

    ; ax/BPB_BytsPerSec ==> ax <- 商   (FATEntry 所在的扇区相对于 FAT 来说的扇区号)
    ; dx <- 余数 (FATEntry 在扇区内的偏移)。
    ; zf: 假设进函数时ax=128，ax*3/2=192，192/512=0,余192，
    ; 因此，第128个扇区对应的FATEntry在FAT项的第0个扇区，偏移192字节处
    mov     bx, [BPB_BytsPerSec]
    div     bx      

    ; 因为在ReadSector函数中使用了dx，所以需要先保存dx
    push    dx

    ; bx <- 0   于是, es:bx = (BaseOfLoader - 100):00 = (BaseOfLoader - 100) * 10h
    mov     bx, 0            

    ; 此句执行之后的 ax 就是 FATEntry 所在的扇区号
    add     ax, SectorNoOfFAT1
    
    ; 读取 FATEntry 所在的扇区, 一次读两个, 避免在边界发生错误, 因为一个 FATEntry 可能跨越两个扇区
    mov     cl, 2
    call    ReadSector        

    ; 在add之前，bx为FATEntry所在扇区的首地址，dx是偏移地址。bx+dx就定位到了该FATEntry。
    pop     dx
    add     bx, dx

    ; ax中为es:bx指向的空间的内容，即：FATEntry的内容
    mov     ax, [es:bx]

    ; 是奇数的簇号还是偶数的簇号？？
    cmp     byte [bOdd], 1

    ; 偶数不需要右移4位，奇数需要
    jnz     LABEL_EVEN_2
    shr     ax, 4

    ; 7654 | 3210(byte1)    7654|3210(byte2)    7654|3210(byte3)
    ; 奇数的簇号，1，偏移为1，
    ; ax是16位，所以读取2B到ax中，根据Big-Endian，ax=7654|3210(byte3)|7654|3210(byte2)，右移4位就可以了。
    ; 偶数簇号，0，偏移为0，
    ; 读入ax后，ax=7654|3210(byte2)|7654|3210(byte1)，不用移动了，低12是我们要的
    
LABEL_EVEN_2:
    ; 我们只需要低12位, and ax,0FFFh。
    and     ax, 0FFFh

LABEL_GET_GAT_ENTRY_OK:
    pop     bx
    pop     es

    ret

; GetFATEntry 结束----------------------------------------------------------------



;----------------------------------------------------------------------------
; 函数名: KillMotor
; 作用:
;   关闭软驱马达，否则软驱的灯会一直亮着
;----------------------------------------------------------------------------

KillMotor:
    push    dx
    
    mov     dx, 03F2h
    mov     al, 0

    out     dx, al

    pop     dx

    ret

; KillMotor 结束----------------------------------------------------------------


; >>>>>>>>>>>>>>>>>>>>>>>> 从此以后的代码在保护模式下执行 <<<<<<<<<<<<<<<<<<<<<<<<
; ===================   32位代码段, 由实模式跳入   =======================

[SECTION .s32]    ; 32位代码段，由实模式跳入

ALIGN    32

[BITS  32]

LABEL_PM_START:
    
    mov    ax, SelectorVideo
    mov    gs, ax          ; 视频段选择子(目的)

    mov    ax, SelectorFlatRW
    mov    ds, ax          ; 数据段选择子->ds，保护模式的段地址都是Selector
    mov    es, ax          ; 数据段选择子->es，保护模式的段地址都是Selector
    mov    fs, ax          ; FS和GS寄存器是从386开始才有的. FS主要用来指向Thread Information Block(TIB).
    
    mov    ss, ax          ; 堆栈段选择子
    mov    esp, TopOfStack ; esp 指向栈底

    ; 显示szMemChkTitle
    push   szMemChkTitle
    call   DispStr
    add    esp, 4

    ; 显示内存信息
    call   DispMemInfo

    ; 建立分页机制
    call   SetupPaging

    mov    ah, 0Fh                         ; 0000: 黑底    1111: 白字
    mov    al, 'P'
    mov    [gs:((80 * 0 + 39) * 2)], ax    ; 屏幕第 0 行, 第 39 列。

    ; 初始化kernel
    call InitKernel

    ;***************************************************************
    ; >>>>>>> TODO: 这一句正式跳转到已加载到内存地址处，开始执行KERNEL的代码
    ; loader 的使命到此结束
    jmp    SelectorFlatC:KernelEntryPointPhyAddr
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
    ; KERNEL 的位置是可变的，通过改变 LOAD.INC 中的 KernelEntryPointPhyAddr 
    ; 和 MAKEFILE 中参数 -Ttext 的值来改变。
    ; 比如，如果把 KernelEntryPointPhyAddr 和 -Ttext 的值都改为 0x400400
    ; 则 KERNEL 就会被加载到内存 0x400000(4M) 处，入口在 0x400400。
    ;
    ;***************************************************************

; ------------------------------------------------------------------------
; DispAL: 显示 AL 中的数字，主要就是一个2进制到16进制转换的过程
; 默认:
;   要显示的位置已经在dwDispPos内存处，数字已经存在 AL 中
;   edi 始终指向要显示的下一个字符的位置
; 被改变的寄存器:
;   ax, edi, ecx
; ------------------------------------------------------------------------
DispAL:
    push    ecx
    push    edx
    push    edi

    mov    edi, [dwDispPos]    ; 显示位置放入edi中，dwDispPos是asm文件中定义的常量

    mov    ah, 0Fh        ; 0000b: 黑底    1111b: 白字
    mov    dl, al         ; al 赋给dl，先把al的值保存起来
    shr    al, 4          ; al右移4位，原来al中的高四位成为低四位
    mov    ecx, 2

.begin:
    and    al, 01111b ; 保留al的低四位，实际上是原来al的高4位，高4位变为0，这时处理的是原来al的高4位
    cmp    al, 9      ; 前者大于后者跳转 ，即al大于9跳转，al小于9不跳转。
    ja     .1         ; JA(jump above）大于则转移到目标指令执行。
    add    al, '0'    ; al小于9还是用数字表示
    jmp    .2         ; 显示出来

.1:
    sub    al, 0Ah    ; al大于9就要转换为16进制，用字母的方式表示
    add    al, 'A'

.2:
    mov    [gs:edi], ax ; al中要显示的数值已经转化为16进制了，就显示出来
    add    edi, 2     ; 已经显示一个字符了，现在移动edi，准备写下一个字符

    mov    al, dl     ; 这时al中低四位就是存放的原来al中的低四位，哇，设计好巧妙。

    loop   .begin     ; 跳转到begin继续执行，这时就是跳转上去处理原来al中的低四位

    mov    [dwDispPos], edi    ; 将下次显示的地址写回到内存dwDispPos处，保证连续

    pop    edi
    pop    edx
    pop    ecx

    ret
; DispAL 结束-------------------------------------------------------------


; ------------------------------------------------------------------------
; 显示当前栈顶下面的一个dword的值，显示格式为"12345678h "
; ------------------------------------------------------------------------
DispInt:
    ;mov    eax, esp
    ;shr    eax, 24            ; 显示最高8位
    ;call   DispAL
    ;mov    eax, esp
    ;shr    eax, 16            ; 显示最高8位
    ;call   DispAL
    ;mov    eax, esp
    ;shr    eax, 8            ; 显示最高8位
    ;call   DispAL
    ;mov    eax, esp
    ;call   DispAL
    ;mov    edi, [dwDispPos]
    ;mov    ah, 07h           ; 0000b: 黑底    0111b: 灰字
    ;mov    al, 'h'
    ;mov    [gs:edi], ax      ; 在上面显示的数字后面加上"h"字符
    ;add    edi, 4            ; 加2是因为显示了一个h，再加2是为了补充一个空格
    ;mov    [dwDispPos], edi

    ; esp是当前栈顶，esp+4就是传入参数的位置，因为esp指向的是ip
    mov    eax, [esp + 4]
    shr    eax, 24            ; 显示最高8位
    call   DispAL

    mov    eax, [esp + 4]
    shr    eax, 16            ; 显示次高8位
    call   DispAL

    mov    eax, [esp + 4]
    shr    eax, 8            ; 显示第三个字节
    call   DispAL

    mov    eax, [esp + 4]
    call   DispAL            ; 显示第四个字节

    push   edi

    mov    edi, [dwDispPos]
    mov    ah, 07h           ; 0000b: 黑底    0111b: 灰字
    mov    al, 'h'
    mov    [gs:edi], ax      ; 在上面显示的数字后面加上"h"字符

    add    edi, 4            ; 加2是因为显示了一个h，再加2是为了补充一个空格
    
    mov    [dwDispPos], edi

    pop    edi

    ret

; DispInt 结束------------------------------------------------------------

; ------------------------------------------------------------------------
; 显示一个字符串
; ------------------------------------------------------------------------
DispStr:
    push   ebp          ; ebp作为存取堆栈指针（存取堆栈中内容时所用到的指针），esp栈顶指针
    
    mov    ebp, esp     ; ebp指向堆栈栈顶esp，注意，这一句不能放到后面，否则ebp指向的位置就不对了
    
    push   ebx          ; 以后要用到bl，所以要压栈先保护起来
    push   esi          ; 源指针
    push   edi          ; 目标指针   

    ; 执行到这儿时ebp，esp的值已经不一样了。esp因为又压了三次所以加了12，ebp还是原来的ebp，push ebp后的堆栈指针

    ; 跳进来之前push szPMMessage  esp-4，push ebp 后esp又-4，esp赋给ebp 所以ebp加8正好指向szPMMessage
    mov    esi, [ebp + 8]    ; pszInfo
    ;mov    esi, szMemChkTitle    ; pszInfo
    mov    edi, [dwDispPos]  ; 显示位置->edi
    mov    ah, 0Fh           ; 黑底白字

.1:
    ;lodsb: 把ds:[esi]处的一个字节赋给al。字符串为"In Protect Mode now. ^-^", 0Ah, 0Ah, 0
    lodsb

    test   al, al     ; 测试寄存器是否为0: test ecx, ecx jz somewhere 如果ecx为零,设置ZF零标志为1,Jz跳转

    jz     .2         ; 结束了，跳转

    cmp    al, 0Ah    ; 回车么？
    jnz    .3         ; 不是回车，直接打印字符

    ; 判断要显示回车，下面是让光标另起一行
    push   eax

    ; edi / 160 执行后al＝当前行号 
    mov    eax, edi
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

    pop    eax

    jmp    .1
    
.3:
    ; 显示字符，移动显示位置
    mov    [gs:edi], ax
    add    edi, 2
    jmp    .1

.2:    ; 要显示的字符串结束了
    mov    [dwDispPos], edi

    pop    edi
    pop    esi
    pop    ebx
    pop    ebp

    ret

; DispStr 结束------------------------------------------------------------

; ------------------------------------------------------------------------
; 换行
; ------------------------------------------------------------------------
DispReturn:
    push    szReturn    ; _szReturn db 0Ah, 0  把0ah，0压入堆栈
    call    DispStr     ; printf("\n");
    add     esp, 4      ; 等于 pop，但是只有寄存器才能pop，这里相当于让esp回到push szReturn前

    ret
; DispReturn 结束---------------------------------------------------------

; ------------------------------------------------------------------------
; 内存拷贝，仿 memcpy
; ------------------------------------------------------------------------
; void* MemCpy(void* es:pDest, void* ds:pSrc, int iSize);
; ------------------------------------------------------------------------

MemCpy:
    push    ebp
    mov     ebp, esp

    push    esi
    push    edi
    push    ecx

    mov     edi, [ebp + 8]    ; Destination
    mov     esi, [ebp + 12]   ; Source
    mov     ecx, [ebp + 16]   ; Counter

.1:
    cmp     ecx, 0            ; 判断是否复制完毕
    jz      .2

    mov     al, [ds:esi]      ;┓
    inc     esi               ;┃
                              ;┣ 逐字节复制 [ds:esi] >>> [es:edi]
    mov byte [es:edi], al     ;┃
    inc     edi               ;┛

    dec     ecx               ; ecx--
    jmp     .1

.2:
    mov     eax, [ebp + 8]    ; 返回值是指向Destination的指针
    
    pop     ecx
    pop     edi
    pop     esi

    mov     esp, ebp
    pop     ebp

    ret

; MemCpy 结束-------------------------------------------------------------



; ------------------------------------------------------------------------
; DispMemInfo: 显示之前15h中断获得的所有内存信息
; ------------------------------------------------------------------------
DispMemInfo:
    push    esi
    push    edi
    push    ecx

    mov     esi, MemChkBuf
    mov     ecx, [dwMCRNumber]  ; for(int i=0;i<[MCRNumber];i++) // 每次得到一个ARDS

.loop:                          ; {

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

; DispMemInfo 结束---------------------------------------------------------



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
    push    ecx            ; 将页表数目存入栈中

    ; 为简化处理, 所有线性地址对应相等的物理地址. 并且不考虑内存空洞.

    ; 初始化PDE
    mov    ax, SelectorFlatRW    ; 该段首地址=0
    mov    es, ax
        
    mov    edi, PageDirBase     ; 偏移地址为PageDirBase

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
    pop    eax            ; 获取页表个数
    mov    ebx, 1024
    mul    ebx

    mov    ecx, eax            ; PTE个数 = PDE个数 * 1024

    mov    edi, PageTblBase    ; 偏移地址为PageTblBase

    xor    eax, eax

    ; 这里是指定每一个页的首地址
    ; 第一个页的首地址是0x00000000，下面没有将0x00000000写上，看起来像是没有地址一样。
    ; zf: 修改地址，不使用0x0000000作为页的起始地址，挪动一两个字节看看
    ; 测试结果，修改地址也起不到预想的作用，因为4k对齐的问题，所以修改的地址必须大于4k
    mov    eax, PG_P | PG_USU | PG_RWW

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



; ------------------------------------------------------------------------
; InitKernel: 将 KERNEL.BIN 的内容经过整理对齐后放到新的位置
;
;     遍历每一个 Program Header，根据 Program Header 
;     中的信息来确定把什么放进内存，放到什么位置，以及放多少。
; ------------------------------------------------------------------------
InitKernel:

    xor    esi, esi

    mov    cx, word [BaseOfKernelFilePhyAddr + 2Ch]  ; ┓ ecx <- pELFHdr->e_phnum
    movzx  ecx, cx                                   ; ┛

    mov    esi, [BaseOfKernelFilePhyAddr + 1Ch]  ; esi <- pELFHdr->e_phoff
    add    esi, BaseOfKernelFilePhyAddr          ; esi <- OffsetOfKernel + pELFHdr->e_phoff

.Begin:    ;  program header table
    ; 打开kernel.bin发现在34位置的是01h,这表示段的类型为PT_LOAD
    ; 标记p_type为PT_LOAD的段，它表明了为运行程序而需要加载到内存的数据
    mov    eax, [esi + 0] 
    cmp    eax, 0            ; PT_NULL == 0 ?

    jz     .NoAction

    ; (void*)(pPHdr->p_vaddr),
    mov    eax, [esi + 04h]               ; eax=0x00
    add    eax, BaseOfKernelFilePhyAddr   ; add eax,00080000h

    ; memcpy( (void*)(pPHdr->p_vaddr), uchCode + pPHdr->p_offset, pPHdr->p_filesz )
    push   dword [esi + 010h]     ; size    ┓
    push   eax                    ; src     ┃   
    push   dword [esi + 08h]      ; dst     ┃   
    call   MemCpy                 ;         ┣   call MemCpy
    add    esp, 12                ;         ┛

.NoAction:

    ; esi += pELFHdr->e_phentsize, esi指向下一个Program Header Entry程序头目录
    add    esi, 020h 
    dec    ecx

    jnz    .Begin

    ret

; InitKernel 结束---------------------------------------------------------



; ===================   32位代码段 END   =======================





; ===================   数据段   =======================

[SECTION .data1]    ; 数据段

ALIGN    32

LABEL_DATA:

; ---------------- 实模式下使用以下符号:

; 字符串
_szMemChkTitle:   db  "BaseAddrL BaseAddrH LengthLow LengthHigh   Type", 0Ah, 0
_szRAMSize:       db  "RAM size:", 0
_szReturn:        db  0Ah, 0

; 变量
_dwMCRNumber:          dd    0    ; Memory Check Result
_dwDispPos:            dd    (80 * 6 + 0) * 2   ; 屏幕第6行, 第 0 列。
_dwMemSize:            dd    0
_ARDStruct:         ; Address Range Descriptor Structure
    _dwBaseAddrLow:    dd    0
    _dwBaseAddrHigh:   dd    0
    _dwLengthLow:      dd    0
    _dwLengthHigh:     dd    0
    _dwType:           dd    0

_MemChkBuf:    times   256  db  0


; ---------------- 保护模式下使用以下符号:
; NASM在表达式中支持两个特殊的记号，即'$'和'$$',它们允许引用当前指令的地址。
; '$'  计算得到它本身所在源代码行的开始处的地址（相对于文件第一行）
; '$$' 计算当前段开始处的地址（相对于文件第一行）

szMemChkTitle   equ     BaseOfLoaderPhyAddr + _szMemChkTitle
szRAMSize       equ     _szRAMSize   + BaseOfLoaderPhyAddr
szReturn        equ     _szReturn    + BaseOfLoaderPhyAddr
dwDispPos       equ     _dwDispPos   + BaseOfLoaderPhyAddr
dwMemSize       equ     _dwMemSize   + BaseOfLoaderPhyAddr
dwMCRNumber     equ     _dwMCRNumber + BaseOfLoaderPhyAddr
ARDStruct       equ     _ARDStruct   + BaseOfLoaderPhyAddr
    dwBaseAddrLow   equ _dwBaseAddrLow  + BaseOfLoaderPhyAddr
    dwBaseAddrHigh  equ _dwBaseAddrHigh + BaseOfLoaderPhyAddr
    dwLengthLow     equ _dwLengthLow    + BaseOfLoaderPhyAddr
    dwLengthHigh    equ _dwLengthHigh   + BaseOfLoaderPhyAddr
    dwType          equ _dwType     + BaseOfLoaderPhyAddr
MemChkBuf       equ     _MemChkBuf  + BaseOfLoaderPhyAddr



; ---------------- 将堆栈放到数据段的末尾
StackSpace:
    times    1000h    db  0

TopOfStack    equ    (BaseOfLoaderPhyAddr + $)    ; 栈顶


; ===================   data1 section END   =======================

