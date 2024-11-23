section .data
	text db "Hello, world!", 10  ;db meaning 'define byte' and 10 is the code to break line

section .text
	global _start

_start:
	mov rax, 1		;rax is the register to the id of the syscall -> rax = 1 ->  1 is the id of the syscall to write
	mov rdi, 1		;rdi is the register to the file descriptor -> rdi = 1 -> 1 is the code to standard output
	mov rsi, text		;rsi is the register to the buffer (location of the string to write) -> rsi = text -> text is the string defined in the data section
	mov rdx, 14		;rdx is the register to the length of the string -> rdx = 14
	syscall			;execute a call using the parameters in the registers

	mov rax, 60		;60 is the id of a syscall to exit
	mov rdi, 0		;0 is the code to no error
	syscall
