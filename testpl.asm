
%if 0

Loader test payload
 by C. Masloch, 2017

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

%endif


%include "lmacros2.mac"

%ifndef _MAP
%elifstr _MAP
%elifempty _MAP
%else	; defined non-empty non-str
	[map all _MAP]
%endif

	cpu 8086
	org 0
payload:
	cmp word [cs:signature], 2638h
	je .sig1_valid
.sig_invalid:
	call error
	db "Signature invalid.", 0

.sig1_valid:
	push ds
	push bx
	mov bx, cs
	add bx, (signature2 -$$+0) >> 4
	mov ds, bx
	cmp word [(signature2 -$$+0) & 0Fh], 2638h
	pop bx
	pop ds
	jne .sig_invalid
	jmp sig_valid

msg:
.error:	db "Test payload error: ", 0
.test:	db "Test payload loaded.", 13, 10, 0

error:
	push cs
	pop ds
	mov si, msg.error
	call disp_msg
	pop si
	call disp_msg
	xor ax, ax
	int 16h
	int 19h

disp_msg:
@@:
	lodsb
	test al, al
	jz @F
	call disp_al
	jmp short @B

disp_al:
	push ax
	push bx
	push bp
	mov ah, 0Eh
	mov bx, 7
	int 10h
	pop bp
	pop bx
	pop ax
@@:
	retn

sig_valid:
		; S0 +28
	pushf	; +26
	sti
	cld
	push ax	; +24
	push bx	; +22
	push cx	; +20
	push dx	; +18
	push si	; +16
	push di	; +14
	push bp	; +12
	mov ax, sp
	add ax, 16
	push ax	; +10 SP
	xor ax, ax
	push ax	; +8 IP
	push cs	; +6
	push ds	; +4
	push es	; +2
	push ss	; +0
	mov si, sp
	 push ss
	 pop ds
	mov di, table
	 push cs
	 pop es
loop_table:
	mov bx, [es:di + 0]
	mov al, 32
	call disp_al
	mov ax, [es:di + 2]
	call disp_al
	xchg al, ah
	call disp_al
	cmp bx, -1
	je @F
	mov al, '='
	call disp_al
	mov ax, [si + bx]
	call disp_ax_hex
@@:
	add di, 4
	cmp di, table.end
	jb loop_table

	push cs
	pop ds
	mov si, msg.test
	call disp_msg
	int3
	xor ax, ax
	int 16h
	int 19h	


disp_ax_hex:			; ax
		xchg al,ah
		call disp_al_hex		; display former ah
		xchg al,ah			;  and fall trough for al
disp_al_hex:			; al
		push cx
		mov cl,4
		ror al,cl
		call disp_al_lownibble_hex	; display former high-nibble
		rol al,cl
		pop cx
						;  and fall trough for low-nibble
disp_al_lownibble_hex:
		push ax			 ; save ax for call return
		and al,00001111b		; high nibble must be zero
		add al,'0'			; if number is 0-9, now it's the correct character
		cmp al,'9'
		jna .decimalnum		 ; if we get decimal number with this, ok -->
		add al,7			;  otherwise, add 7 and we are inside our alphabet
 .decimalnum:
		call disp_al
		pop ax
		retn


	align 2
table:
	dw  +0, "SS"
	dw +12, "BP"
	dw +10, "SP"
	dw  +6, "CS"
	dw  +8, "IP"
	dw +26, "FL"
	db -1, -1, 13,10
	dw  +4, "DS"
	dw +16, "SI"
	dw  +2, "ES"
	dw +14, "DI"
	db -1, -1, 13,10
	dw +24, "AX"
	dw +22, "BX"
	dw +20, "CX"
	dw +18, "DX"
	db -1, -1, 13,10
	dw +28, "S0"
	dw +30, "S1"
	dw +32, "S2"
	dw +34, "S3"
	dw +36, "S4"
	dw +38, "S5"
	dw +40, "S6"
	dw +42, "S7"
	db -1, -1, 13,10
	dw +44, "S8"
	dw +46, "S9"
	dw +48, "SA"
	dw +50, "SB"
	dw +52, "SC"
	dw +54, "SD"
	dw +56, "SE"
	dw +58, "SF"
	db -1, -1, 13,10
.end:

signature:
	dw 2638h
	align 16, db 0

	times 64 * 1024 db 0

signature2:
	dw 2638h
