# sh脚本，用来编译boot.asm并且生成tinix.img文件

# 设置要使用nasm编译的文件名，不能带后缀名
BootFileName=boot
LoaderFileName=loader
KernelFileName=kernel
floppyName=tinix
floppyNameWhenAmount=Tinix_ZF

echo ----- 0. 进入boot文件夹make生成boot.bin和loader.bin
cd boot
make

echo ----- 1. 回到上一级目录
cd ..

echo ----- 2. 挂载软盘
hdiutil mount ./"$floppyName".img

echo ----- 3. 复制kernel.bin到软盘
cp ./"$KernelFileName".bin /Volumes/"$floppyNameWhenAmount"/

echo ----- 4. 复制loder.bin到软盘
cp ./boot/"$LoaderFileName".bin /Volumes/"$floppyNameWhenAmount"/

echo ----- 5. 卸载软盘
hdiutil unmount /Volumes/"$floppyNameWhenAmount"/

echo ===== 6. copy "$BootFileName".bin to first 512B in "$floppyName".img
python ./copyBooterSector.py

echo ----- 7. 复制 "$floppyName".img 到bochs目录
cp ./"$floppyName".img ~/Bochs/Tinix/

echo ^^^^^ 8. run Bochs
cd ~/Bochs/Tinix/
bochs -q -f bochsrc.txt

echo @@@@@@ finish