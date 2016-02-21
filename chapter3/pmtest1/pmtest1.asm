; ==========================================
; pmtest1.asm
; 编译方法：nasm pmtest1.asm -o pmtest1.com
; ==========================================

%include "pm.inc"  ; 常量, 宏, 以及一些说明

org    0100h
       jmp    LABEL_BEGIN     ; 接下来的是gdt数据部分，不是代码，必须要跳过去

[SECTION .gdt]
; GDT
;                                     段基址                段界限    属性
LABEL_GDT:            Descriptor          0,                   0,    0        ; 空描述符
LABEL_DESC_CODE32:    Descriptor          0,    SegCode32Len - 1, DA_C + DA_32 ; 32位代码段
LABEL_DESC_VIDEO:     Descriptor    0B8000h,              0ffffh, DA_DRW ; 数据段，显存首地址

; 这里没有填充LABEL_GDT和LABEL_DESC_CODE32的段基址，因为 段基址=[cs:offset]，现在ds还不知道，所以必须等代码运行以后，确定ds了才能填充

; TODO: 段界限 = SegCode32Len - 1，为什么要减一，不减可以么？？

; GDT END

GdtLen        equ    $ - LABEL_GDT    ; GDT长度
GdtPtr        dw     GdtLen - 1       ; GDT界限
              dd     0                ; GDT基地址，这个是暂时填0，后面ds确定了以后再填充

; GDT 选择子
SeclectorCode32        equ    LABEL_DESC_CODE32 - LABEL_GDT
SeclectorVideo         equ    LABEL_DESC_VIDEO - LABEL_GDT

; END of [SECTION .gdt]


[SECTION .s16]    ; 16位代码段
[BITS  16]

LABEL_BEGIN:
        mov    ax, cs
        mov    ds, ax
        mov    es, ax
        mov    ss, ax
        mov    sp, 0100h       ; TODO: 改成boot是否需要修改sp?

        ; 填充32位代码段描述符的段基址
        xor    eax, eax        ; xor eax,eax与mov eax,0是一样的结果
        mov    ax, cs
        shl    eax, 4
        add    eax, LABEL_SEG_CODE32  ; 段基址 = cs + offset？
        mov	   word [LABEL_DESC_CODE32 + 2], ax
	    shr	   eax, 16
	    mov	   byte [LABEL_DESC_CODE32 + 4], al
	    mov	   byte [LABEL_DESC_CODE32 + 7], ah

	    ; 为加载 GDTR 作准备
	    xor	   eax, eax
	    mov	   ax, ds
	    shl	   eax, 4
	    add	   eax, LABEL_GDT		; eax <- gdt 基地址
	    mov	   dword [GdtPtr + 2], eax	; [GdtPtr + 2] <- gdt 基地址

	    ; 加载 GDTR
	    lgdt   [GdtPtr]

	    ; 关中断
	    cli

	    ; 打开地址线A20
	    in	   al, 92h
	    or	   al, 00000010b
	    out	   92h, al

	    ; 准备切换到保护模式
	    mov    eax, cr0
	    or     eax, 1
	    mov    cr0, eax

	    ; 真正进入保护模式
	    jmp    dword SeclectorCode32:0    ; 执行这一句会把 SelectorCode32 装入 cs, 并跳转到 Code32Selector:0  处

; END of [SECTION .s16]


[SECTION .s32]    ; 32位代码段，由实模式跳入
[BITS  32]

LABEL_SEG_CODE32:
	
        mov    ax, SeclectorVideo
        mov    gs, ax      ; 视频段选择子(目的)

        mov    edi, (80 * 20 + 0) * 2    ; 屏幕第 10 行, 第 0 列。
        mov    ah, 8Ch    ; 0000: 黑底    1100: 红字
        mov    al, 'Z'
        mov    [gs:edi], ax

        ; 到此停止
        jmp    $

SegCode32Len    equ    $ - LABEL_SEG_CODE32
; END of [SECTION .s32]