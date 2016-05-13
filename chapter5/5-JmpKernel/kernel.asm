; ==========================================
; kernel.asm
; 简单的kernel，目前只打印一个字符'F'
;
; 编译链接方法(必须在linux下执行ld，但是生成可执行文件在linux下也不能执行了，因为这段汇编代码在linux下执行没有效果。):
; 注意入口地址030400h是我们在连接时指定的.  
; ld -s -Ttext 0x30400 -o kernel.bin kernel.o  
;
; [root@XXX XXX]# nasm -f elf kernel.asm -o kernel.o
; [root@XXX XXX]# ld -m elf_i386 -s -Ttext 0x30400 -o kernel.bin kernel.o (生成loader使用的bin文件)
; [root@XXX XXX]# 
; ==========================================

; 代码段
[section .text]

global _start    ; 我们必须导出 _start 这个入口，以便让链接器识别。

_start:
    mov    ah, 0Fh                         ; 0000: 黑底    1111: 白字
    mov    al, 'F'
    mov    [gs:((80 * 1 + 39) * 2)], ax    ; 屏幕第 1 行, 第 39 列。

    jmp    $





