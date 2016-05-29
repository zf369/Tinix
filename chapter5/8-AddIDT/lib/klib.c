// ==========================================
// klib.c
// 用C实现的基础函数
// ==========================================

#include "type.h"
#include "const.h"
#include "protect.h"
#include "proto.h"
#include "string.h"
#include "global.h"

/*======================================================================*
                            i_to_a
 * 作用：int to string
 *      数字前面的 0 不被显示出来, 比如 0000B800 被显示成 B800
 *======================================================================*/
PUBLIC char * i_to_a(char *str, int num)
{
    char *p = str;
    char ch;
    int i;
    t_bool flag = FALSE;

    // 0x
    *p = '0';
    p++;
    *p = 'x';
    p++;

    if (num == 0)
    {
        *p = '0';
        p++;
    }
    else
    {
        for (i = 28; i >= 0; i -= 4)
        {
            ch = (num >> i) & 0x0F;
            if (flag || (ch > 0))
            {
                flag = TRUE;

                ch += '0';

                if (ch > '9')
                {
                    ch += 7;
                }

                *p = ch;
                p++;
            }
        }
    }

    // 添加结束符
    *p = 0;

    return str;
}

/*======================================================================*
                               disp_int
 * 作用：将int打印在屏幕上
 *======================================================================*/
PUBLIC void disp_int(int input)
{
    char output[16];
    i_to_a(output, input);
    disp_str(output);
}





