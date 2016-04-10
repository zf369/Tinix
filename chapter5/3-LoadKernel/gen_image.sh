# sh脚本，用来编译boot.asm并且生成tinix.img文件

# 设置要使用nasm编译的文件名，不能带后缀名
BootFileName=boot
LoaderFileName=loader
KernelFileName=kernel
floppyName=tinix
floppyNameWhenAmount=Tinix_ZF

echo 0. 将$KernelFileName.bin导入"$floppyName".img软盘中.
echo 1. 编译"$LoaderFileName".asm，生成"$LoaderFileName".bin文件，并且导入"$floppyName".img软盘中.
echo 2. 编译"$BootFileName".asm，生成"$BootFileName".bin，并且将其复制到"$floppyName".img的前512字节中去.

echo ====== gen loader.bin file
nasm "$LoaderFileName".asm -o "$LoaderFileName".bin

echo +++++++++++ mount "$floppyName".img
hdiutil mount ./"$floppyName".img

echo ------ copy $KernelFileName.bin file
cp ./"$KernelFileName".bin /Volumes/"$floppyNameWhenAmount"/

echo ------ copy $LoaderFileName.bin file
cp ./"$LoaderFileName".bin /Volumes/"$floppyNameWhenAmount"/

echo +++++++++++ unmount "$floppyName".img
hdiutil unmount /Volumes/"$floppyNameWhenAmount"/

echo ====== compiler "$BootFileName".asm
nasm "$BootFileName".asm -o "$BootFileName".bin


echo ------ copy "$BootFileName".bin to first 512B in "$floppyName".img
python ./copyBooterSector.py

echo ------ copy "$floppyName".img
cp ./"$floppyName".img ~/Bochs/Tinix/

echo ^^^^^^ run Bochs
cd ~/Bochs/Tinix/
bochs -q -f bochsrc.txt

echo @@@@@@ finish