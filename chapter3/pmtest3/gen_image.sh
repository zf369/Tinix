# sh脚本，用来编译boot.asm并且生成tinix.img文件

echo 该脚本是用来编译boot.asm并且生成tinix.img文件的 by zf

echo ====== compiler boot.asm
nasm boot.asm -o boot.bin

echo ------ generate tinix.img
# rm ./tinix.img
dd if=boot.bin of=tinix.img bs=512 count=1 conv=notrunc

echo ------ copy tinix.img

cp ./tinix.img ~/Bochs/Tinix/

echo ^^^^^^ run Bochs

cd ~/Bochs/Tinix/

bochs -q -f bochsrc.txt

echo @@@@@@ finish