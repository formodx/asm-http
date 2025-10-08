gcc -o helper helper.c
./helper
nasm -g -F dwarf -f elf64 -o main.o main.asm
gcc -no-pie -o main main.o
rm helper main.o