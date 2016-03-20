; ==========================================
; boot.asm
; 简单的DOS可以识别的引导盘，可以载入loader了
; 使用说明：
;
; 1. 调试状态(开启_BOOT_DEBUG_)：使用test_com.sh一键执行
;    a. 编译出loader.bin和boot.com并且都复制到软盘
;    b. 在虚拟机中运行boot.com即可
;
; 2. 直接引导(关闭_BOOT_DEBUG_)：使用gen_image.sh一键执行
;    a. 编译出loader.bin复制到软盘tinix.img
;    b. 编译出boot.bin，写入到软盘tinix.img的前512B中
;    c. 使用虚拟机运行tinix.img即可
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

BaseOfLoader       equ    09000h       ; LOADER.BIN 被加载到的位置 ----  段地址
OffsetOfLoader     equ    0100h        ; LOADER.BIN 被加载到的位置 ----  偏移地址

RootDirSectors     equ    14           ; 根目录占用的扇区数
SectorNoOfRootDirectory    equ    19   ; 根目录的起始扇区号

;================================================================================================

    ; 跳转到代码处执行
    jmp short LABEL_START
    nop             ; 这个nop用来填充一个字节，因为FAT12格式是从第4字节开始

    ; ------------------------ 下面是 FAT12 磁盘的头 ------------------------
    BS_OEMName        DB    'ForrestY'    ; OEM String, 必须 8 个字节
	BPB_BytsPerSec    DW    512           ; 每扇区字节数
	BPB_SecPerClus    DB    1		      ; 每簇多少扇区
	BPB_RsvdSecCnt    DW    1		      ; Boot 记录占用多少扇区
	BPB_NumFATs       DB    2		      ; 共有多少 FAT 表
	BPB_RootEntCnt    DW    224		      ; 根目录文件数最大值
	BPB_TotSec16      DW    2880		  ; 逻辑扇区总数
	BPB_Media         DB    0xF0		  ; 媒体描述符
	BPB_FATSz16       DW    9		      ; 每FAT扇区数
	BPB_SecPerTrk     DW    18		      ; 每磁道扇区数
	BPB_NumHeads      DW    2		      ; 磁头数(面数)
	BPB_HiddSec       DD    0		      ; 隐藏扇区数
	BPB_TotSec32      DD    0		      ; 如果 wTotalSectorCount 是 0 由这个值记录扇区数
	BS_DrvNum         DB    0		      ; 中断 13 的驱动器号
	BS_Reserved1      DB    0		      ; 未使用
	BS_BootSig        DB    29h		      ; 扩展引导标记 (29h)
	BS_VolID          DD    0		      ; 卷序列号
	BS_VolLab         DB    'Tinix_ZF   ' ; 卷标, 必须 11 个字节
	BS_FileSysType    DB    'FAT12   '	  ; 文件系统类型, 必须 8个字节
    ; ---------------------------------------------------------------------


LABEL_START:
    mov    ax, cs
    mov    ds, ax
    mov    es, ax

    mov    ss, ax
    mov    sp, BaseOfStack

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
    
    mov    dh, 1              ; "Ready.   "的序号
    call   DispStr

    jmp    $                  ; 代码暂时停在这里



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


; times 是一个比较实用伪指令，用来重复定义数据或指令。
times    510-($-$$)    db    0

dw    0xaa55           ; 填写aa55，表明这是一个booter



