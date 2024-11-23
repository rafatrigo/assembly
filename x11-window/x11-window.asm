BITS 64                     ; 64 bits
CPU X64                     ; x86-64 family of CPUs

section .rodata
    sun_path db "/tmp/.X11-unix/X0", 0
    hello_world db "Hello, world!"


section .data

    ; dd - define double word
    ; word = 2 bytes = 16 bits
    ; double word = 4 bytes = 32 bits
    id dd 0                 
    id_base dd 0
    id_mask dd 0
    root_visual_id dd 0


section .text

%define AF_UNIX                 1
%define SOCK_STREAM             1
%define SIZEOF_SOCKADDR_UN      110

%define SYSCALL_READ            0
%define SYSCALL_WRITE           1
%define SYSCALL_POLL            7
%define SYSCALL_SOCKET          41
%define SYSCALL_CONNECT         42
%define SYSCALL_EXIT            60
%define SYSCALL_FCNTL           72

global _start:

_start:
    
    call x11_connect_to_server
  mov r15, rax ; Store the socket file descriptor in r15.

  mov rdi, rax
  call x11_send_handshake

  mov r12d, eax ; Store the window root id in r12.

  call x11_next_id
  mov r13d, eax ; Store the gc_id in r13.

  call x11_next_id
  mov r14d, eax ; Store the font_id in r14.

  mov rdi, r15
  mov esi, r14d
  call x11_open_font


  mov rdi, r15
  mov esi, r13d
  mov edx, r12d
  mov ecx, r14d
  call x11_create_gc

  call x11_next_id
  
  mov ebx, eax ; Store the window id in ebx.

  mov rdi, r15 ; socket fd
  mov esi, eax
  mov edx, r12d
  mov ecx, [root_visual_id]
  mov r8d, 200 | (200 << 16) ; x and y are 200
  %define WINDOW_W 800
  %define WINDOW_H 600
  mov r9d, WINDOW_W | (WINDOW_H << 16)
  call x11_create_window

  mov rdi, r15 ; socket fd
  mov esi, ebx
  call x11_map_window

  mov rdi, r15 ; socket fd
  call set_fd_non_blocking

  mov rdi, r15 ; socket fd
  mov esi, ebx ; window id
  mov edx, r13d ; gc id
  call poll_messages

  ; The end.
  mov rax, SYSCALL_EXIT
  mov rdi, 0
  syscall

; end _start ------------------------------------------------------

; Create a UNIX domain socket and connect to the X11 server.
; @returns The socket file descriptor.
x11_connect_to_server:
    ; prolog
    push rbp
    mov rbp, rsp

    ; open a unix socket: socket(2)
    mov rax, SYSCALL_SOCKET
    mov rdi, AF_UNIX                        ; socket domain - Local
    mov rsi, SOCK_STREAM                    ; socket type - stream oriented
    mov rdx, 0                              ; socket protocol - automatic protocol
    syscall

    ; error checking
    cmp rax, 0
    jle die

    ; store socket file descriptor in rdi to use in the connection
    mov rdi, rax

    ; reserve memory to store sockaddr_un on the stack
    ; sockaddr_un size 108 bytes + 2 bytes to sun_family
    ; and 2 more bytes to be multiple of 16
    sub rsp, 112

    mov word [rsp], AF_UNIX
    lea rsi, sun_path
    mov r14, rdi                            ; save the file descriptor in r14
    ; load effective address
    lea rdi, [rsp + 2]                      ; move the address of rsp + 2 to rdi
                                            ; the destination of the string that now is in rsi

    cld                                     ; clear the direction flag (DF)
                                            ; to ensure that the copy is done forward

    mov ecx, 19                             ; lenght with the null terminator
                                            ; 2 bytes of the AF_UNIX
                                            ; 17 bytes of the sun_path
                                            ; 1 byte the null terminator

    rep movsb                               ; copy

    ; connect to socket: connect(2)
    mov rax, SYSCALL_CONNECT
    mov rdi, r14                            ; move the file descriptor to rdi
    lea rsi, [rsp]
    mov rdx, SIZEOF_SOCKADDR_UN
    syscall

    ; error checking
    cmp rax, 0
    jne die

    mov rax, rdi                            ; move the file descriptor to rax

    ; epilog
    add rsp, 112
    pop rbp
    ret

; end x11_connect_to_server ------------------------------------------


; Send the handshake to the X11 server and read the returned system information.
; @param rdi The socket file descriptor
; @returns The window root id (uint32_t) in rax.
x11_send_handshake:

    push rbp
    mov rbp, rsp

    ; reserve space to the server response to the handshake
    sub rsp, 1<<15                          ; 1<<15 = 2^15 = 32768  -> 32KiB

    ; handshake to the server
    ; docs: https://www.x.org/releases/X11R7.7/doc/xproto/x11protocol.html#Encoding::Connection_Setup
    mov byte [rsp + 0], 'l'                 ; code to little endian
    mov byte [rsp + 2], 11                  ; set major version to 11

    ; send the handshake to the server
    ; rdi already has the file descriptor
    mov rax, SYSCALL_WRITE
    lea rsi, [rsp]
    mov rdx, 12
    syscall
    
    cmp rax, 12                             ; check that all bytes were writen
    jnz die


    ; Read the server response: read(2).
    ; Use the stack for the read buffer.
    ; The X11 server first replies with 8 bytes. Once these are read, it replies with a much bigger message.
    mov rax, SYSCALL_READ
    mov rdi, rdi
    lea rsi, [rsp]
    mov rdx, 8
    syscall

    cmp rax, 8                              ; Check that the server replied with 8 bytes.
    jnz die

    cmp BYTE [rsp], 1                       ; Check that the server sent 'success' (first byte is 1).
    jnz die


    ; Read the rest of the server response: read(2).
    ; Use the stack for the read buffer.
    mov rax, SYSCALL_READ
    mov rdi, rdi
    lea rsi, [rsp]
    mov rdx, 1<<15
    syscall

    cmp rax, 0                              ; Check that the server replied with something.
    jle die

    ; Set id_base globally.
    mov edx, DWORD [rsp + 4]
    mov DWORD [id_base], edx

    ; Set id_mask globally.
    mov edx, DWORD [rsp + 8]
    mov DWORD [id_mask], edx

    ; Read the information we need, skip over the rest.
    lea rdi, [rsp]                          ; Pointer that will skip over some data.
    
    mov cx, WORD [rsp + 16]                 ; Vendor length (v).
    movzx rcx, cx

    mov al, BYTE [rsp + 21]                 ; Number of formats (n).
    movzx rax, al                           ; Fill the rest of the register with zeroes to avoid garbage values.
    imul rax, 8                             ; sizeof(format) == 8

    add rdi, 32                             ; Skip the connection setup
    add rdi, rcx                            ; Skip over the vendor information (v).

    ; Skip over padding.
    add rdi, 3
    and rdi, -4

    add rdi, rax                            ; Skip over the format information (n*8).

    mov eax, DWORD [rdi]                    ; Store (and return) the window root id.

    ; Set the root_visual_id globally.
    mov edx, DWORD [rdi + 32]
    mov DWORD [root_visual_id], edx

    add rsp, 1<<15
    pop rbp
    ret

; end x11_send_handshake -----------------------------------------------------------------------------


; Increment the global id.
; @return The new id.
x11_next_id:

    push rbp
    mov rbp, rsp

    mov eax, DWORD [id] ; Load global id.

    mov edi, DWORD [id_base]                  ; Load global id_base.
    mov edx, DWORD [id_mask]                  ; Load global id_mask.

    ; Return: id_mask & (id) | id_base
    and eax, edx
    or eax, edi

    add DWORD [id], 1                         ; Increment id.

    pop rbp
    ret

; end x11_next_id -----------------------------------------------------------------------------------


; Open the font on the server side.
; @param rdi The socket file descriptor.
; @param esi The font id.
x11_open_font:

    push rbp
    mov rbp, rsp

    %define OPEN_FONT_NAME_BYTE_COUNT 5
    %define OPEN_FONT_PADDING ((4 - (OPEN_FONT_NAME_BYTE_COUNT % 4)) % 4)
    %define OPEN_FONT_PACKET_U32_COUNT (3 + (OPEN_FONT_NAME_BYTE_COUNT + OPEN_FONT_PADDING) / 4)
    %define X11_OP_REQ_OPEN_FONT 0x2d

    sub rsp, 6*8
    mov DWORD [rsp + 0*4], X11_OP_REQ_OPEN_FONT | (OPEN_FONT_NAME_BYTE_COUNT << 16)
    mov DWORD [rsp + 1*4], esi
    mov DWORD [rsp + 2*4], OPEN_FONT_NAME_BYTE_COUNT
    mov BYTE [rsp + 3*4 + 0], 'f'
    mov BYTE [rsp + 3*4 + 1], 'i'
    mov BYTE [rsp + 3*4 + 2], 'x'
    mov BYTE [rsp + 3*4 + 3], 'e'
    mov BYTE [rsp + 3*4 + 4], 'd'


    mov rax, SYSCALL_WRITE
    lea rsi, [rsp]
    mov rdx, OPEN_FONT_PACKET_U32_COUNT*4
    syscall

    cmp rax, OPEN_FONT_PACKET_U32_COUNT*4
    jnz die

    add rsp, 6*8

    pop rbp
    ret

; end x11_open_font ---------------------------------------------------------------------------------


; Create a X11 graphical context.
; @param rdi The socket file descriptor.
; @param esi The graphical context id.
; @param edx The window root id.
; @param ecx The font id.
x11_create_gc:
    push rbp
    mov rbp, rsp

    sub rsp, 8*8

    %define X11_OP_REQ_CREATE_GC 0x37
    %define X11_FLAG_GC_BG 0x00000004
    %define X11_FLAG_GC_FG 0x00000008
    %define X11_FLAG_GC_FONT 0x00004000
    %define X11_FLAG_GC_EXPOSE 0x00010000

    %define CREATE_GC_FLAGS X11_FLAG_GC_BG | X11_FLAG_GC_FG | X11_FLAG_GC_FONT
    %define CREATE_GC_PACKET_FLAG_COUNT 3
    %define CREATE_GC_PACKET_U32_COUNT (4 + CREATE_GC_PACKET_FLAG_COUNT)
    %define MY_COLOR_RGB 0x0000ffff

    mov DWORD [rsp + 0*4], X11_OP_REQ_CREATE_GC | (CREATE_GC_PACKET_U32_COUNT<<16)
    mov DWORD [rsp + 1*4], esi
    mov DWORD [rsp + 2*4], edx
    mov DWORD [rsp + 3*4], CREATE_GC_FLAGS
    mov DWORD [rsp + 4*4], MY_COLOR_RGB
    mov DWORD [rsp + 5*4], 0
    mov DWORD [rsp + 6*4], ecx

    mov rax, SYSCALL_WRITE
    mov rdi, rdi
    lea rsi, [rsp]
    mov rdx, CREATE_GC_PACKET_U32_COUNT*4
    syscall

    cmp rax, CREATE_GC_PACKET_U32_COUNT*4
    jnz die
    
    add rsp, 8*8

    pop rbp
    ret

; end x11_create_gc ---------------------------------------------------------------------


; Create the X11 window.
; @param rdi The socket file descriptor.
; @param esi The new window id.
; @param edx The window root id.
; @param ecx The root visual id.
; @param r8d Packed x and y.
; @param r9d Packed w and h.
x11_create_window:

    push rbp
    mov rbp, rsp

    %define X11_OP_REQ_CREATE_WINDOW 0x01
    %define X11_FLAG_WIN_BG_COLOR 0x00000002
    %define X11_EVENT_FLAG_KEY_RELEASE 0x0002
    %define X11_EVENT_FLAG_EXPOSURE 0x8000
    %define X11_FLAG_WIN_EVENT 0x00000800
    
    %define CREATE_WINDOW_FLAG_COUNT 2
    %define CREATE_WINDOW_PACKET_U32_COUNT (8 + CREATE_WINDOW_FLAG_COUNT)
    %define CREATE_WINDOW_BORDER 1
    %define CREATE_WINDOW_GROUP 1

    sub rsp, 12*8

    mov DWORD [rsp + 0*4], X11_OP_REQ_CREATE_WINDOW | (CREATE_WINDOW_PACKET_U32_COUNT << 16)
    mov DWORD [rsp + 1*4], esi
    mov DWORD [rsp + 2*4], edx
    mov DWORD [rsp + 3*4], r8d
    mov DWORD [rsp + 4*4], r9d
    mov DWORD [rsp + 5*4], CREATE_WINDOW_GROUP | (CREATE_WINDOW_BORDER << 16)
    mov DWORD [rsp + 6*4], ecx
    mov DWORD [rsp + 7*4], X11_FLAG_WIN_BG_COLOR | X11_FLAG_WIN_EVENT
    mov DWORD [rsp + 8*4], 0
    mov DWORD [rsp + 9*4], X11_EVENT_FLAG_KEY_RELEASE | X11_EVENT_FLAG_EXPOSURE


    mov rax, SYSCALL_WRITE
    mov rdi, rdi
    lea rsi, [rsp]
    mov rdx, CREATE_WINDOW_PACKET_U32_COUNT*4
    syscall

    cmp rax, CREATE_WINDOW_PACKET_U32_COUNT*4
    jnz die

    add rsp, 12*8

    pop rbp
    ret

; end x11_create_window ------------------------------------------------------------------------


; Map a X11 window.
; @param rdi The socket file descriptor.
; @param esi The window id.
x11_map_window:

    push rbp
    mov rbp, rsp

    sub rsp, 16

    %define X11_OP_REQ_MAP_WINDOW 0x08
    mov DWORD [rsp + 0*4], X11_OP_REQ_MAP_WINDOW | (2<<16)
    mov DWORD [rsp + 1*4], esi

    mov rax, SYSCALL_WRITE
    mov rdi, rdi
    lea rsi, [rsp]
    mov rdx, 2*4
    syscall

    cmp rax, 2*4
    jnz die

    add rsp, 16

    pop rbp
    ret

; end x11_map_window ------------------------------------------------------------------------------


; Read the X11 server reply.
; @return The message code in al.
x11_read_reply:

    push rbp
    mov rbp, rsp

    sub rsp, 32

    mov rax, SYSCALL_READ
    mov rdi, rdi
    lea rsi, [rsp]
    mov rdx, 32
    syscall

    cmp rax, 1
    jle die

    mov al, BYTE [rsp]

    add rsp, 32

    pop rbp
    ret

; end x11_read_reply --------------------------------------------------------------------------


; Set a file descriptor in non-blocking mode.
; @param rdi The file descriptor.
set_fd_non_blocking:

    push rbp
    mov rbp, rsp

    %define F_GETFL 3
    %define F_SETFL 4

    %define O_NONBLOCK 2048

    mov rax, SYSCALL_FCNTL
    mov rdi, rdi 
    mov rsi, F_GETFL
    mov rdx, 0
    syscall

    cmp rax, 0
    jl die

    ; `or` the current file status flag with O_NONBLOCK.
    mov rdx, rax
    or rdx, O_NONBLOCK

    mov rax, SYSCALL_FCNTL
    mov rdi, rdi 
    mov rsi, F_SETFL
    mov rdx, rdx
    syscall

    cmp rax, 0
    jl die

    pop rbp
    ret

; end set_fd_non_blocking ---------------------------------------------------------------------


; Poll indefinitely messages from the X11 server with poll(2).
; @param rdi The socket file descriptor.
; @param esi The window id.
; @param edx The gc id.
poll_messages:

    push rbp
    mov rbp, rsp

    sub rsp, 32

    %define POLLIN 0x001
    %define POLLPRI 0x002
    %define POLLOUT 0x004
    %define POLLERR  0x008
    %define POLLHUP  0x010
    %define POLLNVAL 0x020

    mov DWORD [rsp + 0*4], edi
    mov DWORD [rsp + 1*4], POLLIN

    mov DWORD [rsp + 16], esi ; window id
    mov DWORD [rsp + 20], edx ; gc id
    mov BYTE [rsp + 24], 0 ; exposed? (boolean)

    .loop:
        mov rax, SYSCALL_POLL
        lea rdi, [rsp]
        mov rsi, 1
        mov rdx, -1
        syscall

        cmp rax, 0
        jle die

        cmp DWORD [rsp + 2*4], POLLERR  
        je die

        cmp DWORD [rsp + 2*4], POLLHUP  
        je die

        mov rdi, [rsp + 0*4]
        call x11_read_reply

        %define X11_EVENT_EXPOSURE 0xc
        cmp eax, X11_EVENT_EXPOSURE
        jnz .received_other_event

        .received_exposed_event:
        mov BYTE [rsp + 24], 1 ; Mark as exposed.

        .received_other_event:

        cmp BYTE [rsp + 24], 1 ; exposed?
        jnz .loop

        .draw_text:
        mov rdi, [rsp + 0*4] ; socket fd
        lea rsi, [hello_world] ; string
        mov edx, 13 ; length
        mov ecx, [rsp + 16] ; window id
        mov r8d, [rsp + 20] ; gc id
        mov r9d, 100 ; x
        shl r9d, 16
        or r9d, 100 ; y
        call x11_draw_text


        jmp .loop


    add rsp, 32
    pop rbp
    ret

; end poll_messages ------------------------------------------------------------------------------


; Draw text in a X11 window with server-side text rendering.
; @param rdi The socket file descriptor.
; @param rsi The text string.
; @param edx The text string length in bytes.
; @param ecx The window id.
; @param r8d The gc id.
; @param r9d Packed x and y.
x11_draw_text:

    push rbp
    mov rbp, rsp

    sub rsp, 1024

    mov DWORD [rsp + 1*4], ecx ; Store the window id directly in the packet data on the stack.
    mov DWORD [rsp + 2*4], r8d ; Store the gc id directly in the packet data on the stack.
    mov DWORD [rsp + 3*4], r9d ; Store x, y directly in the packet data on the stack.

    mov r8d, edx ; Store the string length in r8 since edx will be overwritten next.
    mov QWORD [rsp + 1024 - 8], rdi ; Store the socket file descriptor on the stack to free the register.

    ; Compute padding and packet u32 count with division and modulo 4.
    mov eax, edx ; Put dividend in eax.
    mov ecx, 4 ; Put divisor in ecx.
    cdq ; Sign extend.
    idiv ecx ; Compute eax / ecx, and put the remainder (i.e. modulo) in edx.
    ; LLVM optimizer magic: `(4-x)%4 == -x & 3`, for some reason.
    neg edx
    and edx, 3
    mov r9d, edx ; Store padding in r9.

    mov eax, r8d 
    add eax, r9d
    shr eax, 2 ; Compute: eax /= 4
    add eax, 4 ; eax now contains the packet u32 count.


    %define X11_OP_REQ_IMAGE_TEXT8 0x4c
    mov DWORD [rsp + 0*4], r8d
    shl DWORD [rsp + 0*4], 8
    or DWORD [rsp + 0*4], X11_OP_REQ_IMAGE_TEXT8
    mov ecx, eax
    shl ecx, 16
    or [rsp + 0*4], ecx

    ; Copy the text string into the packet data on the stack.
    mov rsi, rsi ; Source string in rsi.
    lea rdi, [rsp + 4*4] ; Destination
    cld ; Move forward
    mov ecx, r8d ; String length.
    rep movsb ; Copy.

    mov rdx, rax ; packet u32 count
    imul rdx, 4
    mov rax, SYSCALL_WRITE
    mov rdi, QWORD [rsp + 1024 - 8] ; fd
    lea rsi, [rsp]
    syscall

    cmp rax, rdx
    jnz die

    add rsp, 1024

    pop rbp
    ret

; end x11_draw_text -----------------------------------------------------------------------------


die:
    mov rax, SYSCALL_EXIT
    mov rdi, 1
    syscall