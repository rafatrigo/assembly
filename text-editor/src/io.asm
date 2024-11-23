extern open_file_rw
extern close_file
extern read_file
extern write_file
extern exit_0

; define EDIT como sendo o valor ASCII de 'e' que é 101
%define EDIT    'e'
%define VIEW    'v'
%define SAVE    's'
%define QUIT    'q'

section .data
    file_name db "/home/rafatars/Projects/assembly/text-editor/test.txt", 0

    ;escape caracteres
    esc db 0x1b
    arrow_up db 0x1b, '[', 'A'    
    arrow_down db 0x1b, '[', 'B'    
    arrow_right db 0x1b, '[', 'C'    
    arrow_left db 0x1b, '[', 'D'    

section .bss
    file_content resb 10240                     ; reserve 10KB
    input_buffer resb 3                         ; used to store user input during the edit mod
    command resb 1                              ; reserve a byte for the comands

section .text
    global _start

_start:

    mov r13, 0

; starting of the program - opening a file and copying the content to the buffer
    mov r10, file_name

    call open_file_rw

    mov rsi, file_content

    call read_file

; end of the starting fase


; preparing to enter mod_command

    mov byte [command], EDIT                  ; clear the comands

    ; the r15 is a flag to set if a command will be read or not
    ; 0 - not read any command
    ; 1 - read
    xor r15, r15                            ; clear r15 register

    ;TEMPORARY
    mov r15, 1

; entering mod_command
    call mod_command

; end _start ------------------------------------------------------------------------------

; mod_command
;
; description:
;               manage the other mods. through this mode we can:
;               - go to other mods
;               - save the file
;               - quit the program
mod_command:

    cmp r15, 1
    je .exec_command

    jmp mod_command

.exec_command:
    cmp byte [command], EDIT
    mov r15, 0
    mov byte [command], 0
    je mod_edit

    cmp byte [command], VIEW
    mov byte [command], 0
    mov r15, 0
    je mod_view

    cmp byte [command], QUIT
    je exit_0

    ret

; end mod_command -------------------------------------------------------------------------------


mod_edit:

    call listening_to_user_input

    call verify_escape_caractere    

    jmp mod_edit

; end mod_edit -----------------------------------------------------------------------------------


listening_to_user_input:

    ; clean buffer
    mov byte [input_buffer], 0
    mov byte [input_buffer + 1], 0
    mov byte [input_buffer + 2], 0

    mov rax, 0
    mov rdi, 0
    mov rsi, input_buffer
    mov rdx, 3
    syscall

    ret

; end listening_to_user_input --------------------------------------------------------------------------

verify_escape_caractere:
    mov al, [input_buffer]
    cmp al, [esc]
    jne handle_normal_caractere
    

    mov al, byte [input_buffer + 1]
    mov bl, byte [arrow_up + 1]
    cmp al, bl
    jne mod_command                                 ; if the first comparison is equal but this is not
                                                    ; this means that the ESC key was pressed
                                                    ; so we go back to the mod_command

    mov al, byte [input_buffer + 2]
    mov bl, byte [arrow_up + 2] 
    cmp al, bl 
    je handle_arrow_up

    mov al, byte [input_buffer + 2]
    mov bl, byte [arrow_down + 2]  
    cmp al, bl 
    je handle_arrow_down    

    mov al, byte [input_buffer + 2]
    mov bl, byte [arrow_right + 2]  
    cmp al, bl 
    je handle_arrow_right

    mov al, byte [input_buffer + 2]
    mov bl, byte [arrow_left + 2]  
    cmp al, bl 
    je handle_arrow_left

    ret

; end verify_escape_caractere --------------------------------------------------------------

; handle normal caractere
;
; description:
;               write the caractere on the file_content, in the position that is the cursor
;
; input:
;               the input_buffer
; output:
;               update the file_content
handle_normal_caractere:
    cmp byte [input_buffer], 0
    je mod_edit

    ; temporary method just to test
    ; add the value at the position of the cursor in the column
    mov al, [input_buffer]
    mov byte [file_content + r13], al
    inc r13

    cmp byte [input_buffer + 1], 0
    je mod_edit

    mov al, [input_buffer + 1]
    mov [file_content + r13], al
    inc r13

    cmp byte [input_buffer + 2], 0
    je mod_edit

    mov al, [input_buffer + 2]
    mov [file_content + r13], al
    inc r13

    jmp mod_edit

; end handle_normal_caractere ---------------------------------------------------


handle_arrow_up:
    call exit_0

handle_arrow_down:
    call exit_0

handle_arrow_right:
    inc r13
    call mod_edit

handle_arrow_left:
    call exit_0

mod_view:
    call exit_0



