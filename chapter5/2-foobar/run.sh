
nasm -f elf foo.asm -o foo.o
gcc -m32 -c bar.c -o bar.o
ld -m elf_i386 -s foo.o bar.o -o foobar

./foobar
