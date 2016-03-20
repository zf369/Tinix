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

