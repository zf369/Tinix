// ==========================================
// vsprintf.c
// 实现my_vsprintf函数
// ==========================================

#include "type.h"
#include "const.h"
#include "string.h"


/*
 *  为更好地理解此函数的原理，可参考 printf 的注释部分。
 */

/*======================================================================*
                            vsprintf
 *======================================================================*/
int my_vsprintf(char *buf, const char *fmt, va_list args)
{
	char *p;
	char tmp[256];

	va_list p_next_arg = args;

	for (p = buf; *fmt; fmt++)
	{
		if (*fmt != '%')
		{
			*p++ = *fmt;
			continue;
		}

		fmt++;

		switch (*fmt)
		{
		case 'x':
			i_to_a(tmp, *((int *)p_next_arg));
			str_cpy(p, tmp);
			p_next_arg += 4;
			p += str_len(tmp);
			break;

		case 's':
			break;

		default:
			break;
		}
	}

	return (p - buf);
}


