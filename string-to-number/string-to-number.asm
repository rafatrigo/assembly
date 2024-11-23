section .data
	number_str db "23", 10

section .text
	global _start

_start:
	mov rsi, number_str
	
	call str_to_int

	xor rcx, rcx

	mov rax, 60
	mov rdi, 0
	syscall


; convert string to integer
; input: rsi - pointer to string
; output: rax - converted integer	
str_to_int:
    xor rax, rax         ; Zera rax (acumulador para o resultado final)
    xor rcx, rcx         ; Zera rcx (dígito temporário)

.convert_loop:
    movzx rcx, byte [rsi] ; Carrega o próximo byte da string em rcx
    cmp rcx, 0            ; Verifica se é o terminador nulo
    je .done              ; Se for o terminador nulo, termina
    sub rcx, '0'          ; Converte ASCII para dígito
    imul rax, rax, 10     ; Multiplica o acumulador por 10
    add rax, rcx          ; Adiciona o dígito ao acumulador
    inc rsi               ; Move para o próximo byte
    jmp .convert_loop     ; Recomeça o loop

.done:
    ret                   ; Retorna ao chamador

