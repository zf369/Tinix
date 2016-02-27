# sh脚本，用来编译$FileName.asm并且生成$FileName.com文件，并且导入dos软盘中，启动dos系统

# Set FileName param
FileName=pmtest3

echo 用来编译$FileName.asm并且生成$FileName.com文件，并且导入dos软盘中，启动dos系统的 by zf

echo ====== gen .com file
nasm "$FileName".asm -o "$FileName".com

echo +++++++++++ mount b.img
hdiutil mount ~/Bochs/fdos-10meg/b.img

echo ------ copy tinix.img
cp ./"$FileName".com /Volumes/NO\ NAME/

echo +++++++++++ unmount b.img

hdiutil unmount /Volumes/NO\ NAME/

echo ^^^^^^ run Bochs
cd ~/Bochs/fdos-10meg/

bochs -q -f bochsrc.txt

echo @@@@@@ finish