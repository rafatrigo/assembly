section .data
	title db "Sum two numbers", 10
	title_leng equ $ - title
	text1 db "First number: "
	text1_leng equ $ - text1
	text2 db "Second number: "
	text2_leng equ $ -text2
	text3 db "The sum is: "
	text3_leng equ $ - text3

section .bss
	first_num resb 20
	second_num resb 20
	result resb 20

section .text
	global _start

_start:
	call print_title
	call print_text1
	call read_first_num
	call print_text2
	call read_second_num
	call print_text3
	call print_result

	mov rax, 60			; code to sys_exit
	mov rdi, 0			; exit code
	syscall				; make a syscall with the values in the registers

print_title:
	mov rax, 1			; sys_write code
	mov rdi, 1			; unsigned int fd
	mov rsi, title			; const char buffer
	mov rdx, title_leng		; size
	syscall

	ret				; returns to where the function was called

print_text1:
	mov rax, 1
	mov rdi, 1
	mov rsi, text1
	mov rdx, text1_leng
	syscall

	ret

read_first_num:
	mov rax, 0				; sys_read code
	mov rdi, 0
	mov rsi, first_num
	mov rdx, 20				; length of the string
	syscall

	call str_to_int

	mov r8, rax

	ret

print_text2:
	mov rax, 1
	mov rdi, 1
	mov rsi, text2
	mov rdx, text2_leng
	syscall

	ret

read_second_num:
	mov rax, 0
	mov rdi, 0
	mov rsi, second_num
	mov rdx, 20
	syscall

	call str_to_int

	mov r9, rax

	ret

print_text3:
	mov rax, 1
	mov rdi, 1
	mov rsi, text3
	mov rdx, text3_leng
	syscall

	ret

print_result:
	add r8, r9			; sum the values

	mov rax, r8			; rax contains the input for the int_to_str method
	mov rsi, result			; rsi contains the output for the int_to_str method

	call int_to_str

	mov rax, 1
	mov rdi, 1
	mov rsi, result
	mov rdx, r14			; remember that the r14 contains the length of the number
					; that was set on the int_to_str
	syscall

	ret


; convert string to integer
; input: rsi - pointer to string
; output: rax - converted integer	
str_to_int:
    xor rax, rax         		; Zera rax (acumulador para o resultado final)
    xor rcx, rcx         		; Zera rcx (dígito temporário)

.convert_loop:
    movzx rcx, byte [rsi] 		; Carrega o próximo byte da string em rcx
    ;cmp rcx, 0            		; Verifica se é o terminador nulo
    cmp rcx, 10				;verify if is the new line terminator
    je .done              		; Se for o terminador nulo, termina
    sub rcx, '0'          		; Converte ASCII para dígito
    imul rax, rax, 10     		; Multiplica o acumulador por 10
    add rax, rcx          		; Adiciona o dígito ao acumulador
    inc rsi               		; Move para o próximo byte
    jmp .convert_loop     		; Recomeça o loop

.done:
    ret


; convert integer to string
; input: rax - integer to be converted, rsi - output buffer
; output: nothing (result string is on rsi)
int_to_str:
	mov rbx, rsi			; save the pointer to the original buffer
	mov r13, rax			; save the pointer to the original value
	
	call count_int_size

	mov byte [rbx + rcx], 0		; add the null terminator in the end

	mov rsi, rbx			; move back the buffer to the rsi register
	mov rax, r13			; move back the original value to the rax value

	mov r14, rcx			; save the lengh of the int on the r14 register


; convert of integer to ASCII
 
; 1- the buffer starts on the end of the buffer so we decrease it at each interation
; 2- clean the rdx register to store the rest of the division
; 3- divide the value for 10
; 4- get the rest and convert to ASCII
; 5- if the result of the division is 0 stop the process because we come to the end of the number
;    if the result is NOT 0 kepp the process

; example:

; number: 453

; 453/10 = 45 rest= 3

; 45/10 = 4 rest= 5

; 4/10 = 0 rest = 4
.convert_loop:
	dec rcx
	xor rdx, rdx			; clean the rdx register
	mov rdi, 10			; divisor
	div rdi				; divide rax for rcx, the rest is stored in rdx

	add dl, '0'			; dl is the less significant byte of rdx
					; add '0' to convert to ASCII
					; how? imagine that dl = 3, but 3 in ASCII is 51
					; because of that we add with '0',  because '0' in ASCII is 48
					; 48 + 3 = 51 that is 3 in ASCII
					; so this is to convert of integer to ASCII
	
	mov [rsi + rcx], dl		; store digit on the buffer
	test rax, rax			; ferify if the quocient (result of the division) is equal 0
	jnz .convert_loop		; if not 0 restart the loop

	ret

; count the size of an integer value
; input: rax - value
; output: rcx - size of the value
count_int_size:
	xor rcx, rcx			; clean the register
	mov rsi, 10			; quotient

.count_loop:
	xor rdx, rdx			; clean register to avoid arithmetic error or unespected behavior
	inc rcx
	div rsi
	test rax, rax
	jnz .count_loop

	ret

