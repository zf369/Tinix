// ==========================================
// protect.h
// 定义了保护模式需要使用的结构体
// ==========================================

#ifndef _TINIX_PROTECT_H_
#define _TINIX_PROTECT_H_

// 存储段、系统段描述符: 8 bytes
typedef struct s_descriptor
{
	t_16    limit_low;        // Limit
	t_16    base_low;         // Base
	t_8     base_mid;         // Base
	t_8     attr1;            // P(1) DPL(2) DT(1) TYPE(4)
	t_8     limit_high_attr2; // G(1) D(1) 0(1) AVL(1) LimitHight(4)
	t_8     base_high;        // Base
} DESCRIPTOR;

#endif