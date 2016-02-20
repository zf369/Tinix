; 使用宏定义打印输出 
	
	; 当NASM看到'%include'操作符时, 在当前目录搜索
	; 还会搜索'-i'选项在命令行中指定的所有路径。
	; 所以你可以从宏定义库中 包含进一个文件,
	; 比如,输入:
	; nasm -ic:\macrolib\ -f obj myfile.asm
	%include "PrintLib.inc"

	org	   07c00h	; ORG是指定程序被载入内存时,它的起始地址。

	mov	   ax, cs	
	mov    ds, ax   
	mov    es, ax   ; es附加段寄存器, 上面代码就是es = ds = cs
	
	; 背景色如果用了前景色会导致闪烁
	PrintString BootMessage, LenOfBootMessage, display_mode_2, 0h, (ATTR_LIGHTBLUE<<4)|ATTR_LIGHTRED, 1510h

	jmp    $        ; $ 标号表示 nasm 编译后当前指令位置


BootMessage:	db    "Hello, OS world!"
LenOfBootMessage    equ    ($-BootMessage)

	;times 是一个比较实用伪指令，用来重复定义数据或指令。
	times    510-($-$$)    db    0

	dw    0xaa55    ;填写aa55，表明这是一个booter