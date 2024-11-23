;read only
%define O_RDONLY    0
;write only
%define O_WRONLY    1
; read/write
%define O_RDWR      2
;create if not exist
%define O_CREAT     64

section .text
    global open_file_r
    global open_file_rw
    global close_file
    global read_file
    global write_file
    global exit_0
    

; open a file - read only
; input:
;           r10 - file name
; output:
;           r11 - the descriptor of the file
;                 positive integer (if success) / negative integer (if error)
open_file_r:
    mov rax, 2                          ; sys_open
    mov rdi, r10
    mov rsi, O_RDONLY | O_CREAT
    mov rdx, 0644o                      ; permissions - octal value
    syscall

    call verify_opening_error

    mov r11, rax

    ret

; open file - read/write
; create the file if it does not exist
; input:
;           r10 - file name
; output:
;           r11 - the descriptor of the file
;                 positive integer (success) / negative integer (error)
open_file_rw:
    mov rax, 2
    mov rdi, r10
    mov rsi, O_RDWR | O_CREAT         ; flags - read/write and create if not exist
    mov rdx, 0644o                      ; permissions - octal value
                                        ; 0 - prefix of an octal
                                        ; 6 - user permission (read/write)
                                        ; 4 - group permission (read)
                                        ; 4 - other users permission (read)
    syscall

    call verify_opening_error

    mov r11, rax

    ret

; close file
; input:
;           r11 - file descriptor
; output:
;           rax - 0 success / -1 error
close_file:
    mov rax, 3                          ; sys_close
    mov rdi, r11
    syscall

    ; TODO: I don't know if I need to handle errors here
    ; I will ignore it for now, if I get any problem I make a handler here

    ret

; read file
; input:
;           r11 - file description
;           rsi - buffer
; output:
;           rsi - buffer
read_file:
    mov rax, 0                          ; sys_read
    mov rdi, r11
    mov rdx, 10240                      ; size - 10KB
    syscall

    call verify_reading_error

    ret

; write on file
; input:
;           r11 - file descriptor
;           rsi - buffer
; output:
;           rax - number of bytes written
;                 0 - nothing written
;                 -1 - error
write_file:
    call buffer_size

    mov rax, 1                      ; sys_write
    mov rdi, r11
    syscall

    call verify_writing_error

    ret
    
; calculate the buffer size
; input:
;           rsi - buffer
; output:
;           rdx: size of the buffer
buffer_size:
    xor rdx, rdx                       ; clear the register

.count_loop:
    cmp byte [rsi+rdx], 0
    je .done
    inc rdx
    jmp .count_loop

.done:

    ret

; verify error on opening a file
verify_opening_error:
    test rax, rax
    js error_opening                    ; js verify the most significant bit on the flags register
                                        ; if the bit is 1 the result of the previous operation was negative
                                        ; if it is 0 the result was positive
                                        ; js jump if the result was negative

    ret

; verify error on reading
verify_reading_error:
    test rax, rax
    js error_reading

    ret

; verify writing error
verify_writing_error:
    test rax, rax
    js error_writing

    ret

; handle the writing error
error_writing:
    ;TODO: handle error
    jmp exit_0

; handle the opening error
error_opening:
    ;TODO: handle the error
    jmp exit_0

; handle the reading error
error_reading:
    ;TODO: handle the error
    jmp exit_0

; exit the program with exit code 0
exit_0:
    mov rax, 60                         ; sys_exit
    mov rdi, 0
    syscall