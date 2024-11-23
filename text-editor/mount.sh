#!/bin/bash

OUTPUT_FILE="text-editor"

nasm -f elf64 -g -F dwarf src/io.asm -o io.o

nasm -f elf64 -g -F dwarf include/macros.asm -o macros.o

ld io.o macros.o -o $OUTPUT_FILE

# verify mount and linking
if [ $? -eq 0 ]; then
    echo "Mount and linkin - SUCCESS. Executable $OUTPUT_FILE created."
else
    echo "Error to mount or linking."
fi
