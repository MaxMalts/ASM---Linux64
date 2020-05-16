global _start

STDOUT		equ 1
WRITE_CALL	equ 1


section .text
; Writes a character to console
; Input:	ah - character
; Destroy:	rax, rcx, rdx, rdi, rsi, r8-r11
Putc:
	mov [outCharacter], ah
	
	mov rax, WRITE_CALL
	mov rdi, STDOUT
	mov rsi, outCharacter
	mov rdx, 1
	syscall
	
	ret

section .data
outCharacter db 0


section .text
; Calculates the length of string
; Input:	rdi - string address
; Output:	rax - length
; Destroy:      rdi, rcx, rax
Strlen:
        mov al, 0
	xor rcx, rcx
        dec rcx      ; fffffffffffffffH

        repne scasb

	xor rax, rax
        sub rax, 2   ; fffffffffffffffeH
        sub rax, rcx

        ret


; Writes a string to console (must be null-terminated)
; Input:	rdi - string address
; Destroy:	rax, rcx, rdx, rdi, rsi, r8-r11
Puts:
	mov rsi, rdi	; rdi backup
	call Strlen	; In rax is the string length now
	
	mov rdx, rax
	mov rax, WRITE_CALL
	mov rdi, STDOUT
	;rsi already set
	syscall

	ret


; Converts integer to string in givan base
; Input:	eax - number
; 		ecx - base
; Output:	rdi - address to buffer with required number (null-terminated)
; Destroy:	previos number in buffer, eax, edx
IntToBase:
	NUMBUF_SIZE	equ 33D
	
	mov rdi, numBuf + NUMBUF_SIZE - 1
	mov byte [rdi], 0
	dec rdi
	.convert_loop:
		xor edx, edx	; mov edx, 0
		div ecx		; in edx is the quotient
		add dl, '0'	; we "convert" edx to ascii
		
		cmp edx, '9'
		jbe .end_if_letter
			add dl, -'0' - 10D + 'a'
		.end_if_letter:

		mov [rdi], dl	; saving current digit to buffer
		dec rdi
		
		cmp eax, 0
		jne .convert_loop

	inc rdi
	ret

section .data
numBuf times NUMBUF_SIZE db 0


section .text
; Writes a decimal integer to console
; Input:	rdi - address of integer
; Destroy:	rax, rcx, rdx, rdi, rsi, r8-r11
Putd:
	mov eax, [rdi]
	cmp eax, 0
	jge .end_if_negative
		not eax
		inc eax

		push rax	; backup eax
		mov ah, '-'
		call Putc
		pop rax		; restore eax
	.end_if_negative:

	mov ecx, 10D
	call IntToBase	; in rdi is the required string now

	call Puts

	ret


; Writes hex number to console
; Input:	rdi - address of number
; Destroy:	rax, rcx, rdx, rdi, rsi, r8-r11
Putx:
	mov eax, [rdi]
	mov ecx, 16D
	call IntToBase	; in rdi is the required string now

	call Puts

	ret


; Writes binary number to console
; Input:	rdi - address of number
; Destroy:	rax, rcx, rdx, rdi, rsi, r8-r11
Putb:
	mov eax, [rdi]
	mov ecx, 2
	call IntToBase	; in rdi is the required string now

	call Puts

	ret


; Prints a string based on format string and parameters to comsole
; Input:	In stack are the format string and parameters (at the top is
; 			the format string, first parameter is in the secomd place)
; Destroy:	rax, rbx, rcx, rdx, rdi, rsi, r8-r11
Printf:
	pop rbx
	
	pop rcx		; Current character address
	.print_loop:
		cmp byte [rcx], '%'
		jne .if_not_percent
			inc rcx
			xor rax, rax	; Jump table offset
			mov al, [rcx]	; format cpecifier
			
			; Switch format specifier
			cmp al, 'x'
			ja .case_format_default
			
			jmp qword [.jump_table + rax * 8]

			.case_format_c:
				pop rdi		; get parameter
				push rcx	; rcx backup
				mov ah, [rdi]
				call Putc
				pop rcx		; restore rcx

				jmp .end_switch_format
			.case_format_s:
				pop rdi		; get parameter
				push rcx	; rcx backup
				call Puts
				pop rcx		; restore rcx

				jmp .end_switch_format
			.case_format_d:
				pop rdi		; get parameter
				push rcx	; rcx backup
				call Putd
				pop rcx		; restore rcx

				jmp .end_switch_format
			.case_format_x:
				pop rdi		; get parameter
				push rcx	; rcx backup
				call Putx
				pop rcx		; restore rcx

				jmp .end_switch_format
			.case_format_b:
				pop rdi		; get parameter
				push rcx	; rcx backup
				call Putb
				pop rcx		; restore rcx

				jmp .end_switch_format
			.case_format_percent:
				push rcx	; rcx backup
				; ah already set
				call Putc
				pop rcx		; restore rcx

				jmp .end_switch_format
			.case_format_null:
				jmp .return	; end of string
				
			.case_format_default:
				jmp .end_switch_format
			
			.jump_table:	dq .case_format_null,
					times 36d dq .case_format_default
					dq .case_format_percent,
					times 60d dq .case_format_default
					dq .case_format_b,
					dq .case_format_c,
					dq .case_format_d,
					times 14d dq .case_format_default
					dq .case_format_s,
					times 4d dq .case_format_default
					dq .case_format_x,
			
			.end_switch_format:

			inc rcx
			
			jmp .end_if_PercSlash
		.if_not_percent:
			mov ah, [rcx]
			cmp ah, '\'

			jne .skip_bslash
			inc rcx
			mov ah, [rcx]

			; Switch escape character
			cmp ah, 'n'
			je .case_esc_n

			cmp ah, 't'
			je .case_esc_t

			cmp ah, 0
			je .case_esc_null
			jmp .end_switch_esc	; ah will be already set for mirroring

			.case_esc_n:
				mov ah, 0aH
				jmp .end_switch_esc
			.case_esc_t:
				mov ah, 9
				jmp .end_switch_esc
			.case_esc_null:
				jmp .return
			.end_switch_esc:

			
			.skip_bslash:
			push rcx	; rcx backup
			call Putc
			pop rcx		; restore rcx
			
			inc rcx
		.end_if_PercSlash:
		
		cmp byte [rcx], 0
		jne .print_loop
	
	.return:
	push rbx
	ret



_start:
	push number1
	push string2
	push string1
	push character
	push formatString

	call Printf

	mov rax, 03cH
	mov rdi, 0
	syscall

section .data
;formatString db "\n\tTest %s %c %%%s%% %d %b %x \\\a\\ \n\n", 0
;character db 'h'
;string db "string test", 0
;number1 dd -8324756D
;number2 dd 0bef8H

formatString db "\n\t%c %s %s %b\n\n", 0
character db 'I'
string1 db "love", 0
string2 db "EDA", 0
number1 dd 124D

