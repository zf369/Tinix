# Tinix
学习《自己动手写操作系统》一书过程中，自己根据书中每一章写的例子程序。

chapter1 --- boot.asm: 简单的引导文件
          
chapter3 --- pmtest1: 进入保护模式
          |
          |- pmtest2: 从保护模式跳回实模式
          |
          |- pmtest3: 使用LDT
          |
          |- pmtest4: 使用调用门，没有特权级变化
          |
          |- pmtest5: 使用调用门，ring0 -> ring3 -> ring0
          |
          |- pmtest6: 简单使用分页模式，所有线性地址对应相等的物理地址
          |
          |- pmtest7: 分页机制进阶，根据内存数量设计分页
          |
          |- pmtest8: 分页机制终章，切换分页
          |
          |- pmtest9: 设置IDT和8529A，使用时钟中断

chapter4 --- 0-Fat12格式学习: 该目录下放置了几个软盘文件，用于学习FAT12格式。
          |
          |- 1-DOS可以识别的引导盘: 该目录下有一个boot.asm，简单的引导文件，不带loader
          |
          |- 2-带Loader的引导盘: 该目录下有一个boot.asm和loader.asm，可以通过test_com.sh脚本进行dos调试，通过gen_image.sh脚本使用虚拟机运行。(注意_BOOT_DEBUG_的开关)
          |
          |- 3-调用Loader的引导盘: 之前只是查找loader.bin，这里可以跳过去执行了。 

chapter5 --- boot、loader、kernel
          |
          |- 1-hello: 该目录下的hello.asm在linux下编译链接，用来初步了解elf格式。
          |
          |- 2-foobar: 该目录下有一个foo.asm和bar.asm，通过run.sh脚本在ubuntu下编译运行。(修正了书上的错误)
          |
          |- 3-LoadKernel: boot->loader->kernel, loader一直在实模式下
          |
          |- 4-ProtectAndPage:boot->loader, loader进入了保护模式、启用了分页, 复制了kernel.bin到内存
          |
          |- 5-JmpKernel:boot->loader->kernel, loader进入了保护模式、启用了分页，跳转到kernel执行。
          |
          |- 6-ExpandKernel: kernel同时使用了汇编和C，重设了GDT。
          |
          |- 7-KernelTree: 整理了目录结构，编写了Makefile
          |
          |- 8-AddIDT: 为kernel增加了中断处理

chapter6 --- 进程
          |
          |- 1-HelloProcess: 实现了从ring0到ring1的跳转，ring1中一个进程在不断打印，同时时钟中断也不断触发
          |
          |- 2-ClockInterupt: 完善时钟中断处理函数，进行了栈切换，设置EOI，也为进程切换做了准备
          |
          |- 3-ReenterInterupt: 继续完善时钟中断，在中断处理过程中可重入中断
          |
          |- 4-MultiProcess: 在时钟中断中增加进程调度函数，A、B、C三个进程平分CPU时间片
          |
          |- 5-AdvancedInterupt: 对中断函数进行整理，将进中断和出中断的代码收敛在一处
          |
          |- 6-PerfectInterupt: 参考Minix，优化了中断处理函数
          |
          |- 7-SystemCall: 实现了一个简单的系统调用
          |
          |- 8-NewDelay: 通过8253实现了10ms级别的delay函数
          |
          |- 9-PriorityProcess: 实现了优先级不同的进程调度

chapter6 --- 输入输出系统
          |
          |- 1-KeyboardInterupt1: 实现简单的键盘处理系统，可以在屏幕输出非特殊符号
          |
          |- 2-KeyboardInterupt2: 完善了键盘处理系统，可以处理shift、alt等特殊按键
          |
          |- 3-SingleTTY: 增加了TTY和CONSOLE结构体，为多控制台做准备
          |
          |- 4-MultiTTY: 实现了多个控制台
          |
          |- 5-AllKeyboardDeal: 可以处理回车、退格键，也能控制caps lock等灯
          |
          |- 6-Ring3Tasks: 区分Ring3用户进程和Ring1系统任务
          |
