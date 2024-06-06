
%if 0

doubles.asm - Find doubled LBA search strings
 2024 by E. C. Masloch

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

%endif


%include "lmacros3.mac"

	cpu 8086
	org 256
start:
	lframe
	lvar word, meta
	lvar word, data
	lenter
	xor ax, ax
	lvar word, counter
	 push ax
	mov dx, meta
	mov bx, lba_search_metadata

.looppattern:
	mov di, [bx]
	test di, di
	jz .done
	mov cx, [bx + 2]
	mov word [bp + ?data], bx
	mov word [bp + ?meta], dx
	inc word [bp + ?counter]
@@:
	call next
	jz .nextpattern
	cmp word [bx + 2], cx
	jne @B
	mov si, [bx]
	push di
	push cx
	repe cmpsb
	pop cx
	pop di
	jne @B

%if 1
	mov si, msg.double.1
	call disp_msg_si
	mov si, word [bp + ?meta]
	mov ax, [si + 2]
	mov cx, ax
	call disp_ax_hex
	mov si, msg.double.2
	call disp_msg_si
	mov si, dx
	mov ax, [si + 2]
	call disp_ax_hex
	mov si, msg.double.4
	call disp_msg_si
	xor ax, cx
	call disp_ax_hex
	mov si, msg.double.3
	call disp_msg_si
%else
	mov si, msg.double.1
	call disp_msg_si
	mov si, word [bp + ?meta]
	mov si, [si]
	call disp_msg_si
	mov si, msg.double.2
	call disp_msg_si
	mov si, dx
	mov si, [si]
	call disp_msg_si
	mov si, msg.double.3
	call disp_msg_si
%endif

.nextpattern:
	mov bx, word [bp + ?data]
	mov dx, word [bp + ?meta]
	call next
	jmp .looppattern

.done:
	mov ax, word [bp + ?counter]
	mov si, msg.done.1
	call disp_msg_si
	call disp_ax_dec
	mov si, msg.done.2
	call disp_msg_si
	lleave ctx
	mov ax, 4C00h
	int 21h


next:
	add bx, 8
@@:
	cmp word [bx], 0
	lea bx, [bx + 2]
	jne @B
	add dx, 4
	cmp word [bx], 0
	retn


disp_msg_si:
	push di
	push ax
	push bx
	push cx
	push dx

	mov di, si
	mov dx, si
	mov al, 0
	mov cx, -1
	repne scasb
	not cx
	dec cx
	mov ah, 40h
	mov bx, 1
	int 21h

	pop dx
	pop cx
	pop bx
	pop ax
	pop di
	retn


disp_ax_hex:
		xchg al, ah
		call disp_al_hex
		xchg al, ah
disp_al_hex:
		push cx
		mov cl, 4
		ror al, cl
		call .nibble
		ror al, cl
		pop cx
.nibble:
		push ax
		and al, 0Fh
		add al, '0'
		cmp al, '9'
		jbe .isdigit
		add al, 'A'-('9'+1)
.isdigit:
		push dx
		xchg dl, al
		mov ah, 02h
		int 21h
		pop dx
		pop ax
		retn


disp_ax_dec:
decword:
	push dx
	xor dx, dx
	call decdword
	pop dx
	retn


decdword:
	push cx
	xor cx, cx
	call dec_dword_minwidth
	pop cx
	retn


		; Dump dword as decimal number string
		;
		; INP:	dx:ax = dword
		;	cx = minimum width (<= 1 for none, must be < 10)
		;	es:di -> where to store
		; OUT:	es:di -> behind variable-length string
		; CHG:	-
		; STT:	UP
dec_dword_minwidth:
	lframe near
	lequ 12,	bufferlen
	lvar ?bufferlen,buffer
	lenter
	lvar dword,	dividend
	 push dx
	 push ax
	dec cx
	lvar word,	minwidth
	 push cx
	inc cx

	push ax
	push bx
	push cx
	push dx
	push si
	push di
	push es

	 push ss
	 pop es

	lea di, [bp + ?buffer + ?bufferlen - 1]
	mov bx, di
	std			; _AMD_ERRATUM_109_WORKAROUND does not apply
	mov al, '$'
	stosb			; 21.09 dollar terminator

		; dword [bp + ?dividend] = number to display
	mov cx, 10		; divisor
.loop_write:

	xor dx, dx
	push di
	mov di, 4
.loop_divide:
	mov ax, [bp + ?dividend - 2 + di]
	div cx
	mov word [bp + ?dividend - 2 + di], ax
	dec di
	dec di
	jnz .loop_divide
				; dx = last remainder
	pop di
	xchg ax, dx		; ax = remainder (next digit)
				; dword [bp + ?dividend] = result of div
	add al, '0'
	stosb
	dec word [bp + ?minwidth]
	jns .loop_write

	cmp word [bp + ?dividend + 2], 0
	jnz .loop_write
	cmp word [bp + ?dividend], 0
				; any more ?
	jnz .loop_write		; loop -->

	cld

	sub bx, di
	mov cx, bx
	mov dx, di
	inc dx
	push ds
	 push ss
	 pop ds
	mov ah, 09h
	int 21h			; display to stdout
	pop ds

	pop es
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop ax

	lleave
	retn


%include "lbasuch.asm"

	align 2, db 0
meta:
dumpsearches METASEARCHES

dumpsearches METASTRINGS

msg:
.double.1:	asciz "Double detected: "
.double.2:	asciz ", "
.double.4:	asciz " XOR="
.double.3:	asciz 13,10
.done.1:	asciz "Processed "
.done.2:	asciz " strings.",13,10
