; ==========================================
; boot.asm
; 简单的DOS可以识别的引导盘，未载入loader
; ==========================================

; 做 Boot Sector 时一定将此行注释掉!将此行打开后用 nasm Boot.asm -o Boot.com 做成一个.COM文件易于调试
; %define    _BOOT_DEBUG_    

%ifdef    _BOOT_DEBUG_
    org    0100h    ; 调试状态, 做成 .COM 文件, 可调试
%else
    org    07c00h   ; Boot 状态, Bios 将把 Boot Sector 加载到 0:7C00 处并开始执行
%endif

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
	BS_VolLab         DB    'Tinix0.01  ' ; 卷标, 必须 11 个字节
	BS_FileSysType    DB    'FAT12   '	  ; 文件系统类型, 必须 8个字节
    ; ---------------------------------------------------------------------


LABEL_START:
    mov    ax, cs
    mov    ds, ax
    mov    es, ax

    call   DispStr

    jmp    $

DispStr:
    mov    ax, BootMessage    ; 将bootMessage的地址赋值给ax
    mov    bp, ax             ; int10h中断，es:bp是显示字符串的地址
    mov    cx, 16             ; cx计数寄存器, int10h中断中cx=len

    ; ah= 13表示在Teletype模式下显示字符串（Teletype模式？没搞懂）
	; al= 01表示字符串中只含显示字符，其显示属性在bl中
	; 显示后，光标位置改变
	mov    ax, 01301h

	; bx称为基址寄存器
	; bh = 0表示页号为0
	; bl = 0ch，当al = 00h或01h时，使用bl属性
	; bl = 0ch表示黑底红字, 颜色可见《linux》p25
	mov    bx, 005ah

	; dx数据寄存器, 
	; 在进行乘、除运算时，它可作为默认的操作数参与运算，
	; 也可用于存放I/O的端口地址。
	; 在int10h中断中dh表示字符串要显示的行，
	mov    dh, 20		; dh表示字符串在屏幕的多少行显示
	mov    dl, 1        ; dl表示字符串在屏幕的多少列显示

	int    10h    ; 10h号中断

	ret           ; 返回

BootMessage:	db    "Hello, OS world!"

	;times 是一个比较实用伪指令，用来重复定义数据或指令。
	times    510-($-$$)    db    0

	dw    0xaa55    ;填写aa55，表明这是一个booter



