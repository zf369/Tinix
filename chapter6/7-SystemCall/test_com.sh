# sh脚本，用来编译$FileName.asm并且生成$FileName.com文件，并且导入dos软盘中，启动dos系统

# 设置要使用nasm编译的文件名，不能带后缀名
BootFileName=boot
LoaderFileName=loader
KernelFileName=kernel


echo ----- 0. 进入boot文件夹make生成boot.bin和loader.bin
cd boot
make

echo ----- 1. 生成boot.com
nasm -I include/ "$BootFileName".asm -o "$BootFileName".com

echo ----- 2. 回到上一级目录
cd ..

echo +++++++++++ mount b.img
hdiutil mount ~/Bochs/fdos-10meg/b.img

echo ------ copy $KernelFileName.bin file
cp ./"$KernelFileName".bin /Volumes/NO\ NAME/

echo ------ copy $LoaderFileName.bin file
cp ./boot/"$LoaderFileName".bin /Volumes/NO\ NAME/

echo ------ copy $BootFileName.bin file
cp ./boot/"$BootFileName".com /Volumes/NO\ NAME/

echo +++++++++++ unmount b.img
hdiutil unmount /Volumes/NO\ NAME/

echo ^^^^^^ run Bochs
cd ~/Bochs/fdos-10meg/

bochs -q -f bochsrc.txt

echo @@@@@@ finish