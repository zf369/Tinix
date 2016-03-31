; ==========================================
; foo.asm
;
; 编译链接方法(必须在linux下执行ld):
; (ld 的‘-s’选项意为“strip all”)
;
; [root@XXX XXX]# nasm -f elf foo.asm -o foo.o
; [root@XXX XXX]# gcc -c bar.c -o bar.o
; [root@XXX XXX]# ld -m elf_i386 -s foo.o bar.o -o foobar
; [root@XXX XXX]# ./foobar
; the 2nd one
; ==========================================

; EXTERN 跟 C 的关键字 extern 极其相似:
; 它被用来声明一个符号,这个符号在当前模块中没有被定义,但被认为是定义在其他的模块中,
; 但需要在当前模块中对它引用。不是所有的目标文件格式都支持外部变量的:'bin'文 件格式就不行。
extern    choose    ; int choose(int a, int b);

; 数据段
[section .data]

num1st    dd    0x00000003
num2nd    dd    0x00000001

; 代码段
[section .text]

; GLOBAL: 把符号导出到其他模块中。
; GLOBAL和EXTERN是相对的: 
; 如果一个模块声明一个EXTERN的符号,然后引用它, 然后为了防止链接错误
; 另外某一个模块必须确实定义了该符号, 然后把它声明为GLOBAL, 有些汇编器使用名字PUBLIC。
; GLOBAL操作符所作用的符号必须在GLOBAL之后进行定义。
global _start    ; 我们必须导出 _start 这个入口，以便让链接器识别。
global myprint   ; 导出这个函数为了让 bar.c 使用

_start:
    ;mov    eax, 3
    ;push   eax
    ;mov    eax, 30
    ;push   eax 

    ; zf: push num2nd 是错误的, 只有 push [num2nd] 才是push数据，否则是push num2nd 的地址
    push   dword [num2nd]        ; ┓ 
    push   dword [num1st]        ; ┃
    call   choose                ; ┣ choose(num1st, num2nd);
    add    esp, 8                ; ┛ zf: 应该是 add esp, 8

    mov    ebx, 0
    mov    eax, 1        ; sys_exit
    int    0x80          ; 系统调用

; void myprint(char *msg, int len)
myprint:
    mov    edx, [esp + 8]    ; len
    mov    ecx, [esp + 4]    ; msg
    mov    ebx, 1
    mov    eax, 4            ; sys_write
    int    0x80              ; 系统调用
    ret
