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
