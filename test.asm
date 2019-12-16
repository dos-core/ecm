
%if 0

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

%endif


%include "lmacros3.mac"

	cpu 8086
	org 256
start:
do_1:
	mov si, table
.:
	lodsw
	xchg ax, di
	lodsw
	xchg ax, cx
	push si
	push di
	push cx
	call crc16_1			; di -> data, cx = length
	pop cx
	pop di
	pop si

	mov dx, msg.crc16_1.1
	call disp_message
	call disp_ax_hex
	mov dx, msg.2
	call disp_message
	mov ax, cx
	call disp_ax_dec
	mov dx, msg.3
	call disp_message
	mov dx, di
	call disp_message_length_cx
	mov dx, msg.4
	call disp_message

	cmp si, table.end
	jb .


do_2:
	mov si, table
.:
	lodsw
	xchg ax, di
	lodsw
	xchg ax, cx
	push si
	push di
	push cx
	call crc16_2			; di -> data, cx = length
	pop cx
	pop di
	pop si

	mov dx, msg.crc16_2.1
	call disp_message
	call disp_ax_hex
	mov dx, msg.2
	call disp_message
	mov ax, cx
	call disp_ax_dec
	mov dx, msg.3
	call disp_message
	mov dx, di
	call disp_message_length_cx
	mov dx, msg.4
	call disp_message

	cmp si, table.end
	jb .


	mov ax, 4C00h
	int 21h


crc16_1:
	mov si, di
	mov bx, -1
	jcxz .augment
.loop_byte:
	lodsb
	mov dx, (8 << 8) | 80h
.loop_bit:
	mov di, bx
	shl bx, 1
	test al, dl
	jz @F
	inc bx
@@:
	test di, 8000h
	jz @F
	xor bx, 1021h
@@:
	shr dl, 1
	dec dh
	jnz .loop_bit
	loop .loop_byte
.augment:
	mov dh, 16
.loop_augment:
	mov di, bx
	shl bx, 1
	test di, 8000h
	jz @F
	xor bx, 1021h
@@:
	dec dh
	jnz .loop_augment
	xchg ax, bx
	retn


crc16_2:
	inc cx
	and cl, ~1
	shr cx, 1

	mov si, di
	mov bx, -1
	jcxz .augment
.loop_word:
	lodsw
	xchg al, ah
	mov dx, (16 << 8)
	mov bp, 8000h
.loop_bit:
	mov di, bx
	shl bx, 1
	test ax, bp
	jz @F
	inc bx
@@:
	test di, 8000h
	jz @F
	xor bx, 1021h
@@:
	shr bp, 1
	dec dh
	jnz .loop_bit
	loop .loop_word
.augment:
	mov dh, 16
.loop_augment:
	mov di, bx
	shl bx, 1
	test di, 8000h
	jz @F
	xor bx, 1021h
@@:
	dec dh
	jnz .loop_augment
	xchg ax, bx
	retn


	align 4
table:
	dw msg.empty, 0
	dw msg.A, 1
	dw msg.123, msg.123.length
	dw msg.AAA, msg.AAA.length
	dw msg.foobar, msg.foobar.length
.end:


msg:
.crc16_1.1:	asciz "CRC16_1 = "
.crc16_2.1:	asciz "CRC16_2 = "
.2:		asciz ", Length = "
.3:		asciz ", Text = "
.4:		asciz 13,10
.empty:
	db 0
.A:
	db "A"
	db 0
.123:
	db "123456789"
.123.length equ $ - .123
	db 0
.AAA:
	times 256 db "A"
.AAA.length equ $ - .AAA
	db 0
.foobar:
	db "foobar"
.foobar.length equ $ - .foobar
	db 0


		; INP:	ds:dx -> message
		;	cx = length
		; CHG:	-
		; STT:	ds, es don't care
disp_message_length_cx:
	push bx
	push ax
	mov bx, 1
	mov ah, 40h
	int 21h
	pop ax
	pop bx
	retn


		; INP:	ds:dx -> message, ASCIZ
		; CHG:	-
		; STT:	ds, es don't care
disp_message:
	push cx
	push ax
	push di
	push es
	 push ds
	 pop es
	mov di, dx
	mov cx, -1
	mov al, 0
	repne scasb
	pop es
	pop di
	not cx
	dec cx
	call disp_message_length_cx
	pop ax
	pop cx
	retn


		; INP:	al = character to display
		; CHG:	-
		; STT:	ds, es don't care
disp_al:
	push ds
	push dx
	push cx
	push bx
	push ax
	mov dx, sp
	 push ss
	 pop ds
	mov cx, 1
	mov bx, 1
	mov ah, 40h
	int 21h
	pop ax
	pop bx
	pop cx
	pop dx
	pop ds
	retn


		; Display number in ax hexadecimal, always 4 digits
		;
		; INP:	ax = number
		; OUT:	displayed using disp_al
		; CHG:	none
disp_ax_hex:
	xchg al, ah
	call disp_al_hex
	xchg al, ah
disp_al_hex:
	push cx
	mov cl, 4
	rol al, cl
	call disp_al_nybble_hex
	rol al, cl
	pop cx
disp_al_nybble_hex:
	push ax
	and al, 0Fh
	add al, '0'
	cmp al, '9'
	jbe @F
	add al, -'9' -1 +'A'
@@:
	call disp_al
	pop ax
	retn


		; Display number in ax decimal
		;
		; INP:	ax = number
		; OUT:	displayed using disp_al
		; CHG:	none
disp_ax_dec:			; ax (no leading zeros)
		push bx
		xor bx, bx
.pushax:
		push dx
		push ax
		or bl, bl
		jz .nobl
		sub bl, 5
		neg bl
.nobl:
		push cx
		mov cx, 10000
		call .divide_out
		mov cx, 1000
		call .divide_out
		mov cx, 100
		call .divide_out
		mov cl, 10
		call .divide_out
							; (Divisor 1 is useless)
		add al, '0'
		call disp_al
		pop cx
		pop ax
		pop dx
		pop bx					; Caller's register
		retn


		; INP:	ax = number
		;	cx = divisor
		; OUT:	ax = remainder of operation
		;	result displayed
.divide_out:
		push dx
		xor dx, dx
		div cx				; 0:ax / cx
		push dx				; remainder
		dec bl
		jnz .nobl2
		or bh, 1
.nobl2:
		or bh, al
		jz .leadingzero
		add al, '0'
		call disp_al			; display result
 .leadingzero:
		pop ax				; remainder
		pop dx
		retn

