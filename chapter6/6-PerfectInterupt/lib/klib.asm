; ==========================================
; klib.asm
; 用汇编实现并且导出一些基础的函数
;
; 编译方法:
;
; [root@XXX XXX]# nasm -f elf klib.asm -o klib.o
; [root@XXX XXX]# 
; ==========================================

%include "sconst.inc"

; 导入全局变量
extern    disp_pos

; 代码段
[section .text]

global disp_str
global disp_color_str
global out_byte
global in_byte
global enable_irq
global disable_irq

; ------------------------------------------------------------------------
; 显示一个字符串
; ------------------------------------------------------------------------
; void disp_str(char * info);
; ------------------------------------------------------------------------
disp_str:
    push   ebp          ; ebp作为存取堆栈指针（存取堆栈中内容时所用到的指针），esp栈顶指针
    mov    ebp, esp     ; ebp指向堆栈栈顶esp，注意，这一句不能放到后面，否则ebp指向的位置就不对了
    
    push   ebx          ; 以后要用到bl，所以要压栈先保护起来
    push   esi          ; 源指针
    push   edi          ; 目标指针   

    ; 执行到这儿时ebp，esp的值已经不一样了。esp因为又压了三次所以加了12，ebp还是原来的ebp，push ebp后的堆栈指针

    ; 跳进来之前push pszInfo  esp-4，push ebp 后esp又-4，esp赋给ebp 所以ebp加8正好指向pszInfo
    mov    esi, [ebp + 8]    ; pszInfo
    mov    edi, [disp_pos]   ; 显示位置->edi
    mov    ah, 0Fh           ; 黑底白字

.1:
    ;lodsb: 把ds:[esi]处的一个字节赋给al。
    lodsb

    test   al, al     ; 测试寄存器是否为0: test ecx, ecx jz somewhere 如果ecx为零,设置ZF零标志为1,Jz跳转

    jz     .2         ; 结束了，跳转

    cmp    al, 0Ah    ; 回车么？
    jnz    .3         ; 不是回车，直接打印字符

    ; 判断要显示回车，下面是让光标另起一行
    push   eax

    ; edi / 160 执行后al＝当前行号 
    mov    eax, edi
    mov    bl, 160
    div    bl         ;除数位数    隐含的被除数    商    余数    举例
                      ; 8位           AX        AL    AH    DIV  BH
                      ; 16位        DX-AX       AX    DX    DIV  BX
                      ; 32位       EDX-EAX     EAX   EDX    DIV  ECX

    and    eax, 0FFh  ; 只保留行号，列号清0，因为余数在AH中，而余数就是列号？？
    inc    eax        ; eax+＝1，使eax为当前行的下一行
    
    ; eax * 160，eax为当前行的下一行的开始
    mov    bl, 160
    mul    bl         ;乘数位数    隐含的被乘数    乘积的存放位置     举例
                      ; 8位         AL              AX          MUL  BL
                      ; 16位        AX             DX-AX        MUL  BX
                      ; 32位        EAX           EDX-EAX       MUL  ECX

    ; 使edi指向当前行的下一行的开始
    mov    edi, eax

    pop    eax

    jmp    .1
    
.3:
    ; 显示字符，移动显示位置
    mov    [gs:edi], ax
    add    edi, 2
    jmp    .1

.2:    ; 要显示的字符串结束了
    mov    [disp_pos], edi

    pop    edi
    pop    esi
    pop    ebx

    pop    ebp

    ret

; disp_str 结束------------------------------------------------------------



; ------------------------------------------------------------------------
; 显示一个指定颜色的字符串
; ------------------------------------------------------------------------
; void disp_color_str(char * info, int color);
; ------------------------------------------------------------------------
disp_color_str:
    push   ebp          ; ebp作为存取堆栈指针（存取堆栈中内容时所用到的指针），esp栈顶指针
    mov    ebp, esp     ; ebp指向堆栈栈顶esp，注意，这一句不能放到后面，否则ebp指向的位置就不对了
    
    push   ebx          ; 以后要用到bl，所以要压栈先保护起来
    push   esi          ; 源指针
    push   edi          ; 目标指针   

    ; 执行到这儿时ebp，esp的值已经不一样了。esp因为又压了三次所以加了12，ebp还是原来的ebp，push ebp后的堆栈指针

    ; 跳进来之前push pszInfo  esp-4，push ebp 后esp又-4，esp赋给ebp 所以ebp加8正好指向pszInfo
    mov    esi, [ebp + 8]    ; pszInfo
    mov    edi, [disp_pos]   ; 显示位置->edi
    mov    ah,  [ebp + 12]   ; color

.1:
    ;lodsb: 把ds:[esi]处的一个字节赋给al。
    lodsb

    test   al, al     ; 测试寄存器是否为0: test ecx, ecx jz somewhere 如果ecx为零,设置ZF零标志为1,Jz跳转

    jz     .2         ; 结束了，跳转

    cmp    al, 0Ah    ; 回车么？
    jnz    .3         ; 不是回车，直接打印字符

    ; 判断要显示回车，下面是让光标另起一行
    push   eax

    ; edi / 160 执行后al＝当前行号 
    mov    eax, edi
    mov    bl, 160
    div    bl         ;除数位数    隐含的被除数    商    余数    举例
                      ; 8位           AX        AL    AH    DIV  BH
                      ; 16位        DX-AX       AX    DX    DIV  BX
                      ; 32位       EDX-EAX     EAX   EDX    DIV  ECX

    and    eax, 0FFh  ; 只保留行号，列号清0，因为余数在AH中，而余数就是列号？？
    inc    eax        ; eax+＝1，使eax为当前行的下一行
    
    ; eax * 160，eax为当前行的下一行的开始
    mov    bl, 160
    mul    bl         ;乘数位数    隐含的被乘数    乘积的存放位置     举例
                      ; 8位         AL              AX          MUL  BL
                      ; 16位        AX             DX-AX        MUL  BX
                      ; 32位        EAX           EDX-EAX       MUL  ECX

    ; 使edi指向当前行的下一行的开始
    mov    edi, eax

    pop    eax

    jmp    .1
    
.3:
    ; 显示字符，移动显示位置
    mov    [gs:edi], ax
    add    edi, 2
    jmp    .1

.2:    ; 要显示的字符串结束了
    mov    [disp_pos], edi

    pop    edi
    pop    esi
    pop    ebx

    pop    ebp

    ret

; disp_color_str 结束------------------------------------------------------------


; ------------------------------------------------------------------------
; 将value写入到指定port中
; ------------------------------------------------------------------------
; void out_byte(t_port port, t_8 value);
; ------------------------------------------------------------------------
out_byte:
    mov    edx, [esp + 4]      ; port >>>> edx
    mov    al,  [esp + 4 + 4]  ; value >>> al
    out    dx, al

    nop    ; 延迟
    nop

    ret

; out_byte 结束------------------------------------------------------------


; ------------------------------------------------------------------------
; 将指定port的值读取到al中，作为返回值返回
; ------------------------------------------------------------------------
; t_8 in_byte(t_port port);
; ------------------------------------------------------------------------
in_byte:
    mov    edx, [esp + 4]      ; port >>>> edx

    xor    eax, eax
    in     al, dx

    nop    ; 延迟
    nop

    ret

; in_byte 结束------------------------------------------------------------


; ------------------------------------------------------------------------
; 作用：Disable an interrupt request line by setting an 8259 bit. 
; ------------------------------------------------------------------------
; void disable_irq(int irq);
; ------------------------------------------------------------------------
disable_irq:
    mov    ecx, [esp + 4]    ; irq

    pushf    ; push eflags to stack
    cli      ; 关中断，IF在EFLAGS寄存器中，前面已经pushf了，所以这里清中断以后不需要sti，直接popf即可

    mov    ah, 1        ; rol: 循环左移，每次从高位移出的数据位都补到最低位
    rol    ah, cl       ; ah = (1 << (irq % 8)) 
    cmp    cl, 8

    jae    disable_8    ; disable irq >= 8 at the slave 8259

disable_0:
    in     al, INT_M_CTLMASK
    test   al, ah
    jnz    dis_already     ; already disabled?

    or     al, ah
    out    INT_M_CTLMASK, al   ; set bit at master 8259

    popf
    mov eax, 1          ; disabled by this function, return 1
    ret

disable_8:
    in     al, INT_S_CTLMASK
    test   al, ah
    jnz    dis_already     ; already disabled?

    or     al, ah
    out    INT_S_CTLMASK, al   ; set bit at slave 8259

    popf
    mov eax, 1          ; disabled by this function, return 1
    ret

dis_already:

    popf

    xor    eax, eax    ; already disabled, return 0
    ret

; disable_irq 结束------------------------------------------------------------


; ------------------------------------------------------------------------
; 作用: Enable an interrupt request line by clearing an 8259 bit.
; ------------------------------------------------------------------------
; void enable_irq(int irq);
; ------------------------------------------------------------------------
enable_irq:
    mov    ecx, [esp + 4]    ; irq

    pushf
    cli

    mov    ah, ~1
    rol    ah, cl    ; ah = ~(1 << (irq % 8))
    cmp    cl, 8
    jae    enable_8  ; enable irq >= 8 at the slave 8259

enable_0:
    in     al, INT_M_CTLMASK
    and    al, ah
    out    INT_M_CTLMASK, al   ; clear bit at master 8259

    popf
    ret

enable_8:
    in     al, INT_S_CTLMASK
    and    al, ah
    out    INT_S_CTLMASK, al   ; clear bit at slave 8259
    
    popf
    ret

; enable_irq 结束------------------------------------------------------------