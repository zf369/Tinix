; 使用宏定义设置代码的启始地址
	
	; 做BootSector时一定将此行注释掉!
	; 开启后nasm Boot.asm -o Boot.com 做成一个.COM文件易于调试
	%define    _BOOT_DEBUG_

%ifdef _BOOT_DEBUG_
	org	   0100h	; 调试状态, 做成.COM文件, 可调试
%else
	org	   07c00h	; Boot状态, 将加载到0:7C00处并开始执行
%endif

	%include "PrintLib.inc"

	mov	   ax, cs	
	mov    ds, ax   
	mov    es, ax   ; es附加段寄存器, 上面代码就是es = ds = cs
	
	; 背景色如果用了前景色，那么D7=1，会闪烁
	PrintString BootMessage, LenOfBootMessage, display_mode_2, 0h, (ATTR_GREY<<4)|ATTR_GREEN, 1510h

	jmp    $        ; $ 标号表示 nasm 编译后当前指令位置


BootMessage:	db    "Hello, OS world!"
LenOfBootMessage    equ    ($-BootMessage)

	;times 是一个比较实用伪指令，用来重复定义数据或指令。
	times    510-($-$$)    db    0

	dw    0xaa55    ;填写aa55，表明这是一个booter