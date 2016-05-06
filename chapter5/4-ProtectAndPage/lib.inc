; ------------------------------------------------------------------------
; 内存拷贝，仿 memcpy
; ------------------------------------------------------------------------
; void* MemCpy(void* es:pDest, void* ds:pSrc, int iSize);
; ------------------------------------------------------------------------

MemCpy:
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

; MemCpy 结束-------------------------------------------------------------


; ------------------------------------------------------------------------
; DispAL: 显示 AL 中的数字，主要就是一个2进制到16进制转换的过程
; 默认:
;   要显示的位置已经在dwDispPos内存处，数字已经存在 AL 中
;   edi 始终指向要显示的下一个字符的位置
; 被改变的寄存器:
;   ax, edi, ecx
; ------------------------------------------------------------------------
DispAL:
    push    ecx
    push    edx
    push    edi

    mov    edi, [dwDispPos]    ; 显示位置放入edi中，dwDispPos是asm文件中定义的常量

    mov    ah, 0Fh        ; 0000b: 黑底    1111b: 白字
    mov    dl, al         ; al 赋给dl，先把al的值保存起来
    shr    al, 4          ; al右移4位，原来al中的高四位成为低四位
    mov    ecx, 2

.begin:
    and    al, 01111b ; 保留al的低四位，实际上是原来al的高4位，高4位变为0，这时处理的是原来al的高4位
    cmp    al, 9      ; 前者大于后者跳转 ，即al大于9跳转，al小于9不跳转。
    ja     .1         ; JA(jump above）大于则转移到目标指令执行。
    add    al, '0'    ; al小于9还是用数字表示
    jmp    .2         ; 显示出来

.1:
    sub    al, 0Ah    ; al大于9就要转换为16进制，用字母的方式表示
    add    al, 'A'

.2:
    mov    [gs:edi], ax ; al中要显示的数值已经转化为16进制了，就显示出来
    add    edi, 2     ; 已经显示一个字符了，现在移动edi，准备写下一个字符

    mov    al, dl     ; 这时al中低四位就是存放的原来al中的低四位，哇，设计好巧妙。

    loop   .begin     ; 跳转到begin继续执行，这时就是跳转上去处理原来al中的低四位

    mov    [dwDispPos], edi    ; 将下次显示的地址写回到内存dwDispPos处，保证连续

    pop    edi
    pop    edx
    pop    ecx

    ret
; DispAL 结束-------------------------------------------------------------


; ------------------------------------------------------------------------
; 显示当前栈顶下面的一个dword的值，显示格式为"12345678h "
; ------------------------------------------------------------------------
DispInt:
    ;mov    eax, esp
    ;shr    eax, 24            ; 显示最高8位
    ;call   DispAL
    ;mov    eax, esp
    ;shr    eax, 16            ; 显示最高8位
    ;call   DispAL
    ;mov    eax, esp
    ;shr    eax, 8            ; 显示最高8位
    ;call   DispAL
    ;mov    eax, esp
    ;call   DispAL
    ;mov    edi, [dwDispPos]
    ;mov    ah, 07h           ; 0000b: 黑底    0111b: 灰字
    ;mov    al, 'h'
    ;mov    [gs:edi], ax      ; 在上面显示的数字后面加上"h"字符
    ;add    edi, 4            ; 加2是因为显示了一个h，再加2是为了补充一个空格
    ;mov    [dwDispPos], edi

	; esp是当前栈顶，esp+4就是当前栈最上面的有效数据，因为esp指向的是未使用内存
	mov    eax, [esp + 4]
	shr    eax, 24            ; 显示最高8位
	call   DispAL

	mov    eax, [esp + 4]
	shr    eax, 16            ; 显示次高8位
	call   DispAL

	mov    eax, [esp + 4]
	shr    eax, 8            ; 显示第三个字节
	call   DispAL

	mov    eax, [esp + 4]
	call   DispAL            ; 显示第四个字节

	push   edi

	mov    edi, [dwDispPos]
	mov    ah, 07h           ; 0000b: 黑底    0111b: 灰字
	mov    al, 'h'
	mov    [gs:edi], ax      ; 在上面显示的数字后面加上"h"字符

	add    edi, 4            ; 加2是因为显示了一个h，再加2是为了补充一个空格
	
	mov    [dwDispPos], edi

	pop    edi

	ret

; DispInt 结束------------------------------------------------------------

; ------------------------------------------------------------------------
; 显示一个字符串
; ------------------------------------------------------------------------
DispStr:
	push   ebp          ; ebp作为存取堆栈指针（存取堆栈中内容时所用到的指针），esp栈顶指针
	
	mov    ebp, esp     ; ebp指向堆栈栈顶esp，注意，这一句不能放到后面，否则ebp指向的位置就不对了
	
	push   ebx          ; 以后要用到bl，所以要压栈先保护起来
	push   esi          ; 源指针
	push   edi          ; 目标指针   

	; 执行到这儿时ebp，esp的值已经不一样了。esp因为又压了三次所以加了12，ebp还是原来的ebp，push ebp后的堆栈指针

	; 跳进来之前push szPMMessage  esp-4，push ebp 后esp又-4，esp赋给ebp 所以ebp加8正好指向szPMMessage
	mov    esi, [ebp + 8]    ; pszInfo
    ;mov    esi, szMemChkTitle    ; pszInfo
	mov    edi, [dwDispPos]  ; 显示位置->edi
	mov    ah, 0Fh           ; 黑底白字

.1:
    ;lodsb: 把ds:[esi]处的一个字节赋给al。字符串为"In Protect Mode now. ^-^", 0Ah, 0Ah, 0
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
	mov    [dwDispPos], edi

	pop    edi
	pop    esi
	pop    ebx
	pop    ebp

	ret

; DispStr 结束------------------------------------------------------------

; ------------------------------------------------------------------------
; 换行
; ------------------------------------------------------------------------
DispReturn:
    push    szReturn    ; _szReturn db 0Ah, 0  把0ah，0压入堆栈
    call    DispStr     ; printf("\n");
    add     esp, 4      ; 等于 pop，但是只有寄存器才能pop，这里相当于让esp回到push szReturn前

    ret
; DispReturn 结束---------------------------------------------------------

