// ==========================================
// global.c
// 定义了所有用到的全局变量
// ==========================================

#define GLOBAL_VARIABLES_HERE

#include "type.h"
#include "const.h"
#include "protect.h"
#include "proc.h"
#include "tty.h"
#include "console.h"
#include "global.h"
#include "proto.h"

// 进程表
PROCESS    proc_table[NR_TASKS + NR_PROCS];  

// 进程的栈区
char       task_stack[STACK_SIZE_TOTAL];  


// Ring1任务表
TASK       task_table[NR_TASKS] = {
	                                {task_tty, STACK_SIZE_TTY, "tty"}
                                  };
// Ring3任务表
TASK  user_proc_table[NR_PROCS] = {
	                                {TestA, STACK_SIZE_TESTA, "TestA"},
	                                {TestB, STACK_SIZE_TESTB, "TestB"},
	                                {TestC, STACK_SIZE_TESTC, "TestC"}
                                  };

PUBLIC	TTY tty_table[NR_CONSOLES];
PUBLIC	CONSOLE console_table[NR_CONSOLES];

// 中断处理函数指针数组
t_pf_irq_handler irq_table[NR_IRQ]; 

// 系统调用函数表：当前内核实现的所有系统调用函数
t_sys_call sys_call_table[NR_SYS_CALL] = {
											sys_get_ticks,
											sys_write
										 };

