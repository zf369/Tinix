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
global mem_set
global str_cpy
global str_len

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
    


; ------------------------------------------------------------------------
; 内存重置，仿 memset
; ------------------------------------------------------------------------
; void mem_set(void* es:pDest, char ch, int iSize);
; ------------------------------------------------------------------------
mem_set:
    push    ebp
    mov     ebp, esp

    push    esi
    push    edi
    push    ecx

    mov     edi, [ebp + 8]    ; Destination
    mov     edx, [ebp + 12]   ; Char to be putted
    mov     ecx, [ebp + 16]   ; Counter

.1:
    cmp     ecx, 0            ; 判断是否完毕
    jz      .2

    mov byte [es:edi], dl     ;┓
                              ;┣ 逐字节复制 dl >>> [es:edi]
    inc     edi               ;┛

    dec     ecx               ; ecx--
    jmp     .1

.2:

    pop     ecx
    pop     edi
    pop     esi

    mov     esp, ebp
    pop     ebp

    ret
; mem_set 结束-------------------------------------------------------------


; ------------------------------------------------------------------------
; 仿 strcpy
; ------------------------------------------------------------------------
; char *str_cpy(void *p_dst, char *p_src);
; ------------------------------------------------------------------------
str_cpy:
    push    ebp
    mov     ebp, esp

    mov     esi, [ebp + 12]    ; source str
    mov     edi, [ebp + 8]     ; dest str

.1:
    mov     al, [ds:esi]      ;┓
    inc     esi               ;┃
                              ;┣ 逐字节复制 [ds:esi] >>> [es:edi]
    mov byte [es:edi], al     ;┃
    inc     edi               ;┛

    cmp     al, 0    ; is '\0'???
    jnz     .1

.2:
    mov     eax, [ebp + 8]    ; 返回值是指向Destination的指针

    mov     esp, ebp
    pop     ebp

    ret
; str_cpy 结束-------------------------------------------------------------




; ------------------------------------------------------------------------
; 计算字符串长度，仿 strlen
; ------------------------------------------------------------------------
; int str_len(char* p_str);
; ------------------------------------------------------------------------
str_len:
    push    ebp
    mov     ebp, esp

    mov     eax, 0             ; 字符串长度开始是 0
    mov     esi, [ebp + 8]     ; esi指向p_str

.1:
    cmp     byte [esi], 0      ; 看 esi 指向的字符是否是 '\0'

    jz      .2                 ; 如果是 '\0'，程序结束

    inc     esi                ; 如果不是 '\0'，esi 指向下一个字符
    inc     eax                ; 并且，eax++

    jmp     .1

.2:
    mov     esp, ebp
    pop     ebp

    ret

; str_len 结束-------------------------------------------------------------

