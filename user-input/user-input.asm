section .data
	text1 db "Write something here: "
	text2 db "Your text is: "

;bss section is used to reserve memory
section .bss
	yourText resb 16

section .text
	global _start

_start:
	call _printText1
	call _getText
	call _printText2
	call _printYourText

	mov rax, 60
	mov rdi, 0
	syscall

_printText1:
	mov rax, 1
	mov rdi, 1
	mov rsi, text1
	mov rdx, 22
	syscall
	
	ret

_printText2:
	mov rax, 1
	mov rdi, 1
	mov rsi, text2
	mov rdx, 14
	syscall

	ret

_getText:
	mov rax, 0
	mov rdi, 0
	mov rsi, yourText
	mov rdx, 16
	syscall

	ret

_printYourText:
	mov rax, 1
	mov rdi, 1
	mov rsi, yourText
	mov rdx, 16
	syscall

	ret
