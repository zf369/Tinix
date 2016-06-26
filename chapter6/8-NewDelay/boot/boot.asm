; ==========================================
; boot.asm
; DOS可以识别的引导盘，可以载入loader了
; 使用说明：
; 
; 1. 调试状态(开启_BOOT_DEBUG_)：使用test_com.sh一键执行
;    a. 将kernel.bin导入dos软盘中.
;    b. 编译出loader.bin和boot.com并且都复制到软盘
;    c. 在虚拟机中运行boot.com即可
;
; 2. 直接引导(关闭_BOOT_DEBUG_)：使用gen_image.sh一键执行
;    a. 将kernel.bin导入dos软盘中.
;    b. 编译出loader.bin复制到软盘tinix.img
;    c. 编译出boot.bin，写入到软盘tinix.img的前512B中
;    d. 使用虚拟机运行tinix.img即可
; ==========================================

; 做 Boot Sector 时一定将此行注释掉!将此行打开后用 nasm Boot.asm -o Boot.com 做成一个.COM文件易于调试
;%define    _BOOT_DEBUG_    

%ifdef    _BOOT_DEBUG_
    org    0100h    ; 调试状态, 做成 .COM 文件, 可调试
%else
    org    07c00h   ; Boot 状态, Bios 将把 Boot Sector 加载到 0:7C00 处并开始执行
%endif

;================================================================================================

%ifdef    _BOOT_DEBUG_
BaseOfStack    equ    0100h    ; 调试状态下堆栈基地址(栈底, 从这个位置向低地址生长)
%else
BaseOfStack    equ    07c00h   ; Boot状态下堆栈基地址(栈底, 从这个位置向低地址生长)
%endif

%include    "load.inc"

;================================================================================================

    ; 跳转到代码处执行
    jmp short LABEL_START
    nop             ; 这个nop用来填充一个字节，因为FAT12格式是从第4字节开始

; ------------------------ 下面是 FAT12 磁盘的头 ------------------------
%include    "fat12hdr.inc"    
; ---------------------------------------------------------------------


LABEL_START:
    mov    ax, cs
    mov    ds, ax
    mov    es, ax

    mov    ss, ax
    mov    sp, BaseOfStack

    ; 清屏
    mov    ax, 0600h   ; AH = 6, AL = 0h
    mov    bx, 0700h   ; 黑底白字(BH = 07h)
    mov    cx, 0       ; 左上角: (0, 0)
    mov    dx, 0184fh  ; 右下角: (18h, 4fh)
    ; AH=6: 屏幕初始化或上卷
    ; AL = 上卷行数　　AL = 0 全屏幕为空白
    ; BH = 卷入行属性 (BH = 07h) 黑底白字
    ; CH = 左上角行号 CL = 左上角列号 左上角: (0, 0)
    ; DH = 右下角行号 DL = 右下角列号 右下角: (24, 79)
    int    10h

    mov    dh, 0       ; "Booting  "
    call   DispStr

    ; INT13中断详解 功能00H 
	; 功能描述：磁盘系统复位 入口参数：AH＝00H 
	; DL＝驱动器，00H~7FH：软盘；80H~0FFH：硬盘 
	; 出口参数：CF＝0——操作成功，AH＝00H，否则，AH＝状态代码，参见功能号01H中的说明 
    xor    ah, ah    ; ┓
    xor    dl, dl    ; ┣ 软驱复位
    int    13h       ; ┛

    ; ----------- 下面是在软盘的根目录查找loader.bin文件
    mov    word [wSectorNo], SectorNoOfRootDirectory ; wSectorNo=19，根目录开始的扇区

LABEL_SEARCH_IN_ROOT_DIR_BEGIN:
    
    cmp    word [wRootDirSizeForLoop], 0 ; ┓ 判断根目录区是不是已经读完
    jz     LABEL_NO_LOADERBIN            ; ┛ 

    dec    word [wRootDirSizeForLoop]    ; wRootDirSizeForLoop--

    mov    ax, BaseOfLoader
    mov    es, ax             ; es <- BaseOfLoader
    mov    bx, OffsetOfLoader ; bx <- OffsetOfLoader 于是：es:bx = BaseOfLoader:OffsetOfLoader

    mov    ax, [wSectorNo]    ; ax <- 根目录区中的某个扇区号
    mov    cl, 1
    call   ReadSector         ; 将根目录中的当前扇区读取到es:bx处

    mov    si, LoaderFileName ; ds:si -> "LOADER  BIN"
    mov    di, OffsetOfLoader ; di = OffsetOfLoader  
                              ; es:di BaseOfLoader:0100 = BaseOfLoader*10h+100
                              ; 文件名在每个目录条目的最开始，所以es:di指的就是第一个条目的文件名

    cld                       ; cld使DF 复位，即是让DF=0，std使DF置位，即DF=1.

    mov    dx, 10h            ; 因为一个扇区最多有512/32=16个根目录

LABEL_SEARCH_FOR_LOADERBIN:
    cmp    dx, 0                              ; ┓循环次数控制,如果已经读完了一个扇区,
    jz     LABEL_GOTO_NEXT_SECTOR_IN_ROOT_DIR ; ┛就跳到下一个

    dec    dx                  ; dx--

    mov    cx, 11              ; "LOADER  BIN" 11字节

LABEL_CMP_FILENAME:

	cmp    cx, 0
	jz     LABEL_FILENAME_FOUND ; 11个字符都相等, 表示找到

	dec    cx                   ; cx--

	lodsb                       ; ds:si -> al

	cmp    al, byte [es:di]     ; 比较当前字符是否和di指向的字符相等

	jz     LABEL_GO_ON

	jmp    LABEL_DIFFERENT      ; 字符不相等，表面当前DirectoryEntry不是loader.bin

LABEL_GO_ON:
    inc    di                   ; di++ 准备比较下一个字符
    jmp    LABEL_CMP_FILENAME   ; 继续比较

LABEL_DIFFERENT:
    and    di, 0FFE0h           ; ┓	di &= E0 为了让它指向本条目开头，每个条目是32字节对齐，所以低5位肯定=0
    add    di, 20h              ; ┛ di += 20h  下一个目录条目
    mov    si, LoaderFileName   ; si重新指向"LOADER  BIN"字符串

    jmp    LABEL_SEARCH_FOR_LOADERBIN ; 接着比较下一个文件

LABEL_GOTO_NEXT_SECTOR_IN_ROOT_DIR:
    add    word [wSectorNo], 1             ; 读取的根目录区的扇区号+1
    jmp    LABEL_SEARCH_IN_ROOT_DIR_BEGIN  ; 继续查找新的扇区里面的文件是否有loader.bin

LABEL_NO_LOADERBIN:
    mov    dh, 2              ; "No LOADER."的序号
    call   DispStr

%ifdef    _BOOT_DEBUG_
    ; INT 21是计算机中断的一种，不同的AH值表示不同的中断功能。4CH号功能——带返回码结束程序。AL=返回码
    mov    ax, 4c00h    ; ┓4CH号功能——带返回码结束程序。AL=返回码
    int    21h          ; ┛没有找到 LOADER.BIN, 回到DOS
%else
    jmp    $            ; booter没有找到loader，停在这里
%endif


LABEL_FILENAME_FOUND:         ; 找到loader.bin以后jmp到这里继续执行
    
    ; 先查找loader.bin文件的条目中存储的起始簇号(即起始扇区号)
    and    di, 0FFE0h           ; ┓ di &= E0 为了让它指向本条目开头，每个条目是32字节对齐，所以低5位肯定=0
    add    di, 01Ah             ; ┛ di += 1Ah  起始簇号
    mov    cx, word [es:di]     ; 将簇号放入cx
    push   cx                   ; 保存簇号，后面还要用

    mov    ax, RootDirSectors   ; ax = 14 (即根目录区总扇区)
    add    cx, ax               ; cx = cx + 14
    add    cx, DeltaSectorNo    ; cx = 17 + 14 + 起始簇号，实际上是: cx = 19 + 14 + (簇号-2)
                                ; cx 里面变成 LOADER.BIN 的起始扇区号 (从 0 开始数的序号)

    mov    ax, BaseOfLoader
    mov    es, ax               ; es <- BaseOfLoader
    mov    bx, OffsetOfLoader   ; bx <- OffsetOfLoader  
                                ; es:bx=BaseOfLoader:OffsetOfLoader
    
    mov    ax, cx               ; ax = loader.bin起始扇区号

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
    ; 显示Ready字符串
    mov    dh, 1              ; "Ready.   "的序号
    call   DispStr

; ***************************************************************************
    
    ; 这一句正式跳转到已加载到内存中的 LOADER.BIN 的开始处，开始执行 LOADER.BIN 的代码
    ; Boot Sector 的使命到此结束
    jmp    BaseOfLoader:OffsetOfLoader               

; ***************************************************************************



;============================================================================
;变量
;----------------------------------------------------------------------------
wRootDirSizeForLoop    dw    RootDirSectors    ; 根目录占用的扇区数，在循环中会递减到0
wSectorNo              dw    0                 ; 要读取的扇区号
bOdd                   db    0                 ; 奇偶标识位
;============================================================================


;============================================================================
;字符串
;----------------------------------------------------------------------------
; loader.bin文件名(注意，在目录区文件名都是大写，文件名8字节，不足8字节补充空格，后缀名3字节)
LoaderFileName         db    "LOADER  BIN", 0  

; 为简化代码, 下面每个字符串的长度均为 MessageLength
messageLength          equ    9

BootMessage            db     "Booting  "    ; 9字节, 不够则用空格补齐. 序号 0
Message1               db     "Ready.   "    ; 9字节, 不够则用空格补齐. 序号 1
Message2               db     "No Loader"    ; 9字节, 不够则用空格补齐. 序号 2
;============================================================================



;----------------------------------------------------------------------------
; 函数名: DispStr
; 作用:
;	显示一个字符串, 函数开始时 dh 中应该是字符串序号(0-based)
;----------------------------------------------------------------------------
DispStr:
    mov    ax, messageLength  ; 将messageLength赋值给ax
    mul    dh                 ; ax = dh * messageLength，即数组的offset

    add    ax, BootMessage    ; ax = BootMessage + offset，即数组对应的元素地址

    mov    bp, ax             ; ┓
    mov    ax, ds             ; ┣ int10h中断，es:bp是显示字符串的地址
    mov    es, ax             ; ┛

    mov    cx, messageLength  ; cx计数寄存器, int10h中断中cx=len

    ; ah= 13表示在Teletype模式下显示字符串（Teletype模式？没搞懂）
	; al= 01表示字符串中只含显示字符，其显示属性在bl中
	; 显示后，光标位置改变
	mov    ax, 01301h

	; bx称为基址寄存器
	; bh = 0表示页号为0
	; bl = 0ch，当al = 00h或01h时，使用bl属性
	; bl = 0ch表示黑底红字, 颜色可见《linux》p25
	mov    bx, 000ch

	; dx数据寄存器, 
	; 在进行乘、除运算时，它可作为默认的操作数参与运算，
	; 也可用于存放I/O的端口地址。
	; 在int10h中断中dh表示字符串要显示的行，
	mov    dh, 0 		; dh表示字符串在屏幕的多少行显示
	mov    dl, 1        ; dl表示字符串在屏幕的多少列显示

	int    10h    ; 10h号中断

	ret           ; 返回

; DispStr 结束----------------------------------------------------------------




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

    mov     ax, BaseOfLoader    ; ┓
    sub     ax, 0100h           ; ┣ 在 BaseOfLoader 前面留出4K(段基址，0100h还要乘上个10h)空间存放FAT
    mov     es, ax              ; ┛ 

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


; times 是一个比较实用伪指令，用来重复定义数据或指令。
times    510-($-$$)    db    0

dw    0xaa55           ; 填写aa55，表明这是一个booter

