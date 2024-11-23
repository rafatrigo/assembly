section .bss
	string resb 20

section .text
	global _start

_start:
	mov rax, 2345
	mov rsi, string

	call int_to_str

	;print string
	mov rax, 1
	mov rdi, 1
	mov rsi, string
	mov rdx, r14			; remember that r14 contains the lengh of the int value
					; this was set on the int_to_str function
	syscall

	mov rax, 60
	mov rdi, 0
	syscall



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

	;inc rcx
	ret
