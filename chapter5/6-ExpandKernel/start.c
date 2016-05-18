// ==========================================
// start.c
// 和汇编交互调用的函数
// ==========================================

#include "type.h"
#include "const.h"
#include "protect.h"

PUBLIC void *mem_cpy(void *pDst, void *pSrc, int iSize);
PUBLIC void disp_str(char *pszInfo);

// 全局变量，汇编也需要使用
PUBLIC t_8        gdt_ptr[6];    // gdt pointer: 0~15:Limit  16~47:Base
PUBLIC DESCRIPTOR gdt[GDT_SIZE];

/*======================================================================*
                            cstart
 *======================================================================*/
PUBLIC void cstart()
{
	disp_str("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n -------- \"cstart\" begins ------\n");

	// 将Loader中的GDT pointer复制到gdt中
	// gdt_ptr[6] 共 6 个字节：0~15:Limit  16~47:Base。
	mem_cpy(&gdt,                                   // New GDT
		    (void *)(*((t_32 *)(&gdt_ptr[2]))),     // Base of old GDT
		    *((t_16 *)(&gdt_ptr[0])) + 1            // Limit of old GDT
		   );

	// gdt_ptr[6] 共 6 个字节：0~15:Limit  16~47:Base。
	t_16 *pGdtLimit = (t_16 *)(&gdt_ptr[0]);
	t_32 *pGdtBase = (t_32 *)(&gdt_ptr[2]);

	*pGdtLimit = GDT_SIZE * sizeof(DESCRIPTOR) - 1;
	*pGdtBase = (t_32)(&gdt);
}







