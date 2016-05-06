# sh脚本，用来编译$FileName.asm并且生成$FileName.com文件，并且导入dos软盘中，启动dos系统

# 设置要使用nasm编译的文件名，不能带后缀名
BootFileName=boot
LoaderFileName=loader
KernelFileName=kernel

echo 0. 将$KernelFileName.bin导入dos软盘中.
echo 1. 编译$LoaderFileName.asm并且生成$LoaderFileName.bin文件，并且导入dos软盘中.
echo 2. 编译$BootFileName.asm并且生成$BootFileName.com文件，并且导入dos软盘中，启动dos系统的 by zf

echo ====== gen loader.bin file
nasm "$LoaderFileName".asm -o "$LoaderFileName".bin

echo ====== gen boot.com file
nasm "$BootFileName".asm -o "$BootFileName".com

echo +++++++++++ mount b.img
hdiutil mount ~/Bochs/fdos-10meg/b.img

echo ------ copy $KernelFileName.bin file
cp ./"$KernelFileName".bin /Volumes/NO\ NAME/

echo ------ copy $LoaderFileName.bin file
cp ./"$LoaderFileName".bin /Volumes/NO\ NAME/

echo ------ copy $BootFileName.bin file
cp ./"$BootFileName".com /Volumes/NO\ NAME/

echo +++++++++++ unmount b.img
hdiutil unmount /Volumes/NO\ NAME/

echo ^^^^^^ run Bochs
cd ~/Bochs/fdos-10meg/

bochs -q -f bochsrc.txt

echo @@@@@@ finish