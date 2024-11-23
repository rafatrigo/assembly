nasm -f elf64 -g -F dwarf x11-window.asm -o x11-window.o

ld x11-window.o -o x11-window