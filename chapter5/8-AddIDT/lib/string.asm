; ==========================================
; string.asm
; 用汇编实现并且导出string相关的函数
;
; 编译方法:
;
; [root@XXX XXX]# nasm -f elf string.asm -o string.o
; [root@XXX XXX]# 
; ==========================================

; 代码段
[section .text]

global mem_cpy

; ------------------------------------------------------------------------
; 内存拷贝，仿 memcpy
; ------------------------------------------------------------------------
; void* mem_cpy(void* es:pDest, void* ds:pSrc, int iSize);
; ------------------------------------------------------------------------

mem_cpy:
    push    ebp
    mov     ebp, esp

    push    esi
    push    edi
    push    ecx

    mov     edi, [ebp + 8]    ; Destination
    mov     esi, [ebp + 12]   ; Source
    mov     ecx, [ebp + 16]   ; Counter

.1:
    cmp     ecx, 0            ; 判断是否复制完毕
    jz      .2

    mov     al, [ds:esi]      ;┓
    inc     esi               ;┃
                              ;┣ 逐字节复制 [ds:esi] >>> [es:edi]
    mov byte [es:edi], al     ;┃
    inc     edi               ;┛

    dec     ecx               ; ecx--
    jmp     .1

.2:
    mov     eax, [ebp + 8]    ; 返回值是指向Destination的指针
    
    pop     ecx
    pop     edi
    pop     esi

    mov     esp, ebp
    pop     ebp

    ret

; mem_cpy 结束-------------------------------------------------------------
    





