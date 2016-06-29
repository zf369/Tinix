// ==========================================
// global.c
// 定义了所有用到的全局变量
// ==========================================

#define GLOBAL_VARIABLES_HERE

#include "type.h"
#include "const.h"
#include "protect.h"
#include "proto.h"
#include "proc.h"
#include "global.h"

// 进程表
PROCESS    proc_table[NR_TASKS];  

// 进程的栈区
char       task_stack[STACK_SIZE_TOTAL];  


// 任务表
TASK       task_table[NR_TASKS] = {
	                                {TestA, STACK_SIZE_TESTA, "TestA"},
	                                {TestB, STACK_SIZE_TESTB, "TestB"},
	                                {TestC, STACK_SIZE_TESTC, "TestC"}
                                  };

// 中断处理函数指针数组
t_pf_irq_handler irq_table[NR_IRQ]; 

// 系统调用函数表：当前内核实现的所有系统调用函数
t_sys_call sys_call_table[NR_SYS_CALL] = {
											sys_get_ticks
										 };

