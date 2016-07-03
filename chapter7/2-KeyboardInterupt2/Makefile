## !!! 注意：只能在linux下make，在MAC上无法make

######################
# Makefile for Tinix #
######################

# Entry point of Tinix
# It must be as same as 'KernelEntryPointPhyAddr' in load.inc!!!
ENTRYPOINT	= 0x30400

# Offset of entry point in kernel file
# It depends on ENTRYPOINT
ENTRYOFFSET	=   0x400

# Programs, flags, etc.
ASM      = nasm
DASM     = ndisasm
CC       = gcc
LD       = ld

ASMBFLAGS = -I boot/include/
ASMKFLAGS = -I include/ -f elf
# 一些版本的gcc编译时常会出现 undefined reference to `__stack_chk_fail'的错误
# 可以在makefile的CFLAGS中添加-fno-stack-protector一项。
CFLAGS    = -I include/ -c -m32 -fno-stack-protector
LDFLAGS   = -m elf_i386 -s -Ttext $(ENTRYPOINT)
DASMFLAGS = -u -o $(ENTRYPOINT) -e $(ENTRYOFFSET)

# This Program
TINIXBOOT   = boot/boot.bin boot/loader.bin
TINIXKERNEL = kernel.bin
OBJS        = kernel/kernel.o kernel/syscall.o kernel/start.o kernel/main.o kernel/clock.o\
              kernel/global.o kernel/i8259.o kernel/protect.o kernel/proc.o\
              lib/klib.o lib/klibc.o lib/string.o kernel/keyboard.o kernel/tty.o
DASMOUTPUT  = kernel.bin.asm

# All Phony Targets
# PHONY 目标并非实际的文件名：只是在显式请求时执行命令的名字。
# 有两种理由需要使用PHONY 目标：避免和同名文件冲突，改善性能。
.PHONY : everything bootonly kernelonly final image clean realclean disasm all buildimg

# Default starting position
everything : $(TINIXBOOT) $(TINIXKERNEL)

bootonly : $(TINIXBOOT)

kernelonly : $(TINIXKERNEL)

all : realclean everything

final : all clean

image : final buildimg

clean :
	rm -f $(OBJS)

realclean :
	rm -f $(OBJS) $(TINIXKERNEL) $(TINIXBOOT)

disasm : 
	$(DASM) $(DASMFLAGS) $(TINIXKERNEL) > $(DASMOUTPUT)

buildimg :
	echo "buildimg is null. Use shell script instead on MAC!!!"
	# mount TINIX.IMG /mnt/floppy -o loop
	# cp -f boot/loader.bin /mnt/floppy/
	# cp -f kernel.bin /mnt/floppy
	# umount  /mnt/floppy

# MakeFile语法：
# target : prerequisites
#	command
# 上述形式的格式代表两层含义：
# 1. 要想得到target，需要执行命令command。
# 2. target依赖prerequisites，当prerequisites中至少有一个文件比target文件新时，command才被执行。
boot/boot.bin : boot/boot.asm boot/include/load.inc boot/include/fat12hdr.inc
	$(ASM) $(ASMBFLAGS) -o $@ $<

# $@ 代表 target;
# $< 代表prerequisites的第一个名字；
# $(ASM) $(ASMBFLAGS) -o $@ $<
# 等价于：
# nasm -I include/ -o loader.bin loader.asm
boot/loader.bin : boot/loader.asm boot/include/load.inc boot/include/fat12hdr.inc boot/include/pm.inc
	$(ASM) $(ASMBFLAGS) -o $@ $<

$(TINIXKERNEL) : $(OBJS)
	$(LD) $(LDFLAGS) -o $(TINIXKERNEL) $(OBJS)

kernel/kernel.o : kernel/kernel.asm include/sconst.inc
	$(ASM) $(ASMKFLAGS) -o $@ $<

kernel/syscall.o : kernel/syscall.asm include/sconst.inc
	$(ASM) $(ASMKFLAGS) -o $@ $<

kernel/start.o : kernel/start.c include/type.h include/const.h include/protect.h \
                 include/proto.h include/string.h include/proc.h include/global.h
	$(CC) $(CFLAGS) -o $@ $<

kernel/main.o : kernel/main.c include/type.h include/const.h include/protect.h \
                 include/proto.h include/string.h include/proc.h include/global.h
	$(CC) $(CFLAGS) -o $@ $<

kernel/i8259.o : kernel/i8259.c include/type.h include/const.h include/protect.h \
                                include/proto.h include/string.h include/global.h
	$(CC) $(CFLAGS) -o $@ $<

kernel/global.o : kernel/global.c include/type.h include/const.h \
  include/protect.h include/proto.h include/proc.h include/global.h
	$(CC) $(CFLAGS) -o $@ $<

kernel/protect.o : kernel/protect.c include/type.h include/const.h \
  include/protect.h include/proto.h include/string.h include/global.h include/proc.h
	$(CC) $(CFLAGS) -o $@ $<

kernel/clock.o: kernel/clock.c include/type.h include/const.h include/protect.h \
  include/proto.h include/proc.h include/global.h
	$(CC) $(CFLAGS) -o $@ $<

lib/proc.o : kernel/proc.c include/type.h include/const.h include/protect.h \
  include/proto.h include/string.h include/proc.h include/global.h
	$(CC) $(CFLAGS) -o $@ $<

lib/keyboard.o : kernel/keyboard.c include/type.h include/const.h include/protect.h \
  include/proto.h include/string.h include/proc.h include/global.h include/keymap.h include/keyboard.h
	$(CC) $(CFLAGS) -o $@ $<

kernel/tty.o: kernel/tty.c include/type.h include/const.h include/protect.h include/proto.h include/string.h \
  include/proc.h include/global.h include/keyboard.h
	$(CC) $(CFLAGS) -o $@ $<

lib/klibc.o : lib/klib.c include/type.h include/const.h include/protect.h \
  include/proto.h include/string.h include/proc.h include/global.h
	$(CC) $(CFLAGS) -o $@ $<

lib/klib.o : lib/klib.asm include/sconst.inc
	$(ASM) $(ASMKFLAGS) -o $@ $<

lib/string.o : lib/string.asm
	$(ASM) $(ASMKFLAGS) -o $@ $<



