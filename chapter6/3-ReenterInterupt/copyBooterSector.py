#!/usr/bin/env python
#encoding=utf-8

import os
import shutil

def copyBooterSectorToFloppy(booter, floppy):
	if (os.path.exists(booter) == False):
		print '!!!!!! File Not Found: ', booter
		return

	if (os.path.exists(floppy) == False):
		print '!!!!!! File Not Found: ', floppy
		return

	# 读取booter文件512字节
	print '====== Start to read from ', booter

	booterFile = open(booter, 'rb');
	booterDatas = booterFile.read(512)
	booterFile.close();

	# print '----- datas: ', booterDatas;

	# 将读取booter文件的512字节写入到软盘的前512字节中
	print '====== Start to write to ', floppy
	floppyFile = open(floppy, 'rb+')
	floppyFile.seek(0)
	floppyFile.write(booterDatas)
	floppyFile.close();


# Script starts from here

booterFileName = 'boot/boot.bin'
floppyFileName = 'tinix.img'

copyBooterSectorToFloppy(booterFileName, floppyFileName)

print '*******Done.'
