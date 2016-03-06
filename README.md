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
