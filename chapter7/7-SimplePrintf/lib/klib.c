// ==========================================
// klib.c
// 用C实现的基础函数
// ==========================================

#include "type.h"
#include "const.h"
#include "protect.h"
#include "string.h"
#include "proc.h"
#include "tty.h"
#include "console.h"
#include "global.h"
#include "proto.h"

/*======================================================================*
                            is_alphanumeric
 * 作用：判断是否是可打印的字符
 *======================================================================*/
PUBLIC t_bool is_alphanumeric(char ch)
{
    if (ch < ' ' || ch > '~')
    {
        return FALSE;
    }

    return TRUE;
}

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

/*======================================================================*
                               delay
 * 作用：延迟
 *======================================================================*/
PUBLIC void delay(int time)
{
    int i, j, k;
    for (k = 0; k < time; k++)
    {
        // for (j = 0; j < 10000; j++) // for Virtual PC
        for (j = 0; j < 10; j++) // for Bochs
        {
            for (i = 0; i < 10000; i++)
            {
                // nop
                ;
            }
        }
    }
}




