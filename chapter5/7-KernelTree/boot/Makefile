# Makefile for boot

# Programs, flags, etc.
ASM      = nasm
# ASMFLAGS = 
ASMFLAGS = -I include/

# This Program
TARGET   = boot.bin loader.bin

# All Phony Targets
# PHONY 目标并非实际的文件名：只是在显式请求时执行命令的名字。
# 有两种理由需要使用PHONY 目标：避免和同名文件冲突，改善性能。
.PHONY : everything clean all

# Default starting position
everything : $(TARGET)

clean :
	rm -f $(TARGET)

all : clean everything

# MakeFile语法：
# target : prerequisites
#	command
# 上述形式的格式代表两层含义：
# 1. 要想得到target，需要执行命令command。
# 2. target依赖prerequisites，当prerequisites中至少有一个文件比target文件新时，command才被执行。
boot.bin : boot.asm ./include/load.inc ./include/fat12hdr.inc
	$(ASM) $(ASMFLAGS) -o $@ $<

# $@ 代表 target;
# $< 代表prerequisites的第一个名字；
# $(ASM) $(ASMFLAGS) -o $@ $<
# 等价于：
# nasm -I include/ -o loader.bin loader.asm
loader.bin : loader.asm ./include/load.inc ./include/fat12hdr.inc ./include/pm.inc
	$(ASM) $(ASMFLAGS) -o $@ $<
