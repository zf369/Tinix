; 最基本的boot.asm，带有丰富的注释，后续会不断修改，但是没有这么多注释
	
	org	   07c00h	; ORG是指定程序被载入内存时,它的起始地址。

	; 不能直接给段寄存器赋值，应该先给通用寄存器赋值，然后再传给段寄存器
	mov	   ax, cs	; ax是累加器，快, cs是代码段寄存器
	mov    ds, ax   ; ds数据段寄存器
	mov    es, ax   ; es附加段寄存器, 上面代码就是es = ds = cs
	
	; CALL要push返回地址存入堆栈的, 以便ret返回 jmp直接跳
	call   DispStr	; call == push eip + jmp

	jmp    $        ; $ 标号表示 nasm 编译后当前指令位置

DispStr:
	mov    ax, BootMessage     ; 将bootMessage的地址赋值给ax
	mov    bp, ax              ; int10h中断，es:bp是显示字符串的地址
	mov    cx, 16              ; cx计数寄存器, int10h中断中cx=len

	; 当调用int10h中断时，使用ax设置功能
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