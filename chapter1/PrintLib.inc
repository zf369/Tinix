; PrintLib.inc文件中定义了一个向屏幕输出字符串信息的宏

%ifndef PrintLib
	%define PrintLib

; 此宏在实模式下使用，属于BIOS子功能调用
 
	; 显示模式

	; 字符串只包含字符码，显示之后不更新光标位置，属性值在BL中
    %define display_mode_1 00h 
    ; 字符串只包含字符码，显示之后更新光标位置，属性值在BL中
    %define display_mode_2 01h 
    ; 字符串包含字符码及其属性值，显示之后不更新光标位置
    %define display_mode_3 02h 
    ; 字符串包含字符码及其属性值，显示之后更新光标位置
	%define display_mode_4 03h 

	;背景及字体格式属性值
	%define ATTR_BLACK   0h
	%define ATTR_BLUE    01h
	%define ATTR_GREEN   02H
	%define ATTR_PURPLE   03h
	%define ATTR_RED     04h
	%define ATTR_MAGENTA   05h
	%define ATTR_BROWN   06h
	%define ATTR_GREYISH   07h
	%define ATTR_GREY    08h
	%define ATTR_LIGHTBLUE 09h
	%define ATTR_LIGHTGREEN 0Ah
	%define ATTR_LIGHTPURPLE 0Bh
	%define ATTR_LIGHTRED  0Ch
	%define ATTR_LIGHTMAGENTA 0Dh
	%define ATTR_YELLOW   0Eh
	%define ATTR_WHITE  0Fh
	  
	; 参数： 1.要显示的字符串标号  
	; 2.要显示的字符串的长度值
	; 3.显示模式
	; 4.视频页号
	; 5.当显示模式选3和4时为0h，否则需要背景和字符的格式属性值
	; 6.显示的列和行
; 例子: PrintString BootMessage,LenOfBootMessage,display_mode_2,0h,(ATTR_BLACK<<4)|ATTR_GREEN,0000h
	
	; '%macro'一行上宏名后面的数字'1'定义了宏可以接收的参数的个数。 宏定义里面的'%1'是用来引用宏调用中的第一个参数。对于一个有多 个参数的宏,参数序列可以这样写:'%2','%3'等等。
	%macro PrintString 6

	; push register used
	push ax
	push bp
	push cx
	push bx
	push dx

	mov ax, %1
	mov bp, ax    ; 字符串地址->bp

	mov cx, %2    ; length->cx

	mov ax, (01300h + %3)    ; 显示模式->ax

	mov bx, (%4 + %5)    ; 视频页号+颜色属性->bx

	mov dx, %6    ; 打印在屏幕上的行列号->dx

	int 10h

	; pop register used
	pop dx
	pop bx
	pop cx
	pop bp
	pop ax

	%endmacro

%endif