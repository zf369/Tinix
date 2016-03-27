; ==========================================
; hello.asm
; 编译链接以后可以直接在控制台输出：Hello, world!
;
; 编译链接方法(必须在linux下执行ld):
; (ld 的‘-s’选项意为“strip all”)
;
; [root@XXX XXX]# nasm -f elf hello.asm -o hello.o
; [root@XXX XXX]# ld -m elf_i386 -s hello.o -o hello
; [root@XXX XXX]# ./hello
; Hello, world!
; ==========================================

; 数据段
[section .data]

strHello    db    "Hello, world!", 0Ah
STRLEN      equ   ($ - strHello)

; 代码段
[section .text]

; GLOBAL: 把符号导出到其他模块中。
; GLOBAL和EXTERN是相对的: 
; 如果一个模块声明一个EXTERN的符号,然后引用它, 然后为了防止链接错误
; 另外某一个模块必须确实定义了该符号, 然后把它声明为GLOBAL, 有些汇编器使用名字PUBLIC。
; GLOBAL操作符所作用的符号必须在GLOBAL之后进行定义。
global _start    ; 我们必须导出 _start 这个入口，以便让链接器识别。

_start:
    mov    edx, STRLEN
    mov    ecx, strHello
    mov    ebx, 1
    mov    eax, 4        ; sys_write
    int    0x80          ; 系统调用

    mov    ebx, 0
    mov    eax, 1        ; sys_exit
    int    0x80          ; 系统调用