
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
		; S0 +28
	pushf	; +26

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

	align 4
.foundname:
	times 8+1+3+1 db 0
		; buffer for base name (8) + dot (1) + ext (3) + NUL (1)
	align 2
.foundname_none:
	asciz "(None)"
.foundname_none_size: equ $ - .foundname_none
	align 2
.names:
	dw .name_first, 0
	dw .name_second, 0
	dw .name_third, 0
	dw .name_fourth, 0
	dw 0
.name_first:	asciz "1st name"
.name_second:	asciz "2nd name"
.name_third:	asciz "3rd name"
.name_fourth:	asciz "4th name"
.name_before:	asciz ": "
.name_quote:	asciz '"'
.name_after:	asciz 13,10


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
;	pushf	; +26
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


		; INP:	ds:si -> first byte to check for name
		;	cx = number of bytes left
		; OUT:	(8+1+3+1)bytes[msg.foundname] = found name,
		;	 converted to 8.3 ASCIZ format,
		;	 "(None)" if none
		;	CY if no filename found,
		;	 si = INP:si + INP:cx
		;	 cx = 0
		;	NC if filename found,
		;	 si -> byte behind the name, thus (si-11)-> name
		;	 cx = number of bytes left
		; CHG:	di, ax
		; STT:	ds = es
findname:
.:
	cmp cx, 11		; enough for another name ?
	jb .none		; no -->
				; (cx == 0 jumps here too)
.check:
	push cx
	push si
	mov cx, 11
	lodsb
	mov ah, al		; check for same char in all 11 places
	cmp al, 32		; first character must not be blank
	je .check_fail		; if it is -->
;	cmp al, 5		; first character may be 05h to indicate 0E5h
;	je .check_pass
	db __TEST_IMM8		; (skip lodsb)
.check_loop_same:
	lodsb
	cmp ah, al
	jne .check_loop_differs
	call .check_character
	jc .check_fail
	loop .check_loop_same
		; if we arrive here, all characters (while valid) are the
		;  same character repeated 11 times. we disallow this in case
		;  that the padding character is an allowed one (eg '&' 26h).
.check_fail:
	pop si
	pop cx
	dec cx			; lessen the counter
	inc si			; -> next position to check
	jmp .

.check_character:
	cmp al, 32
	jb .check_character_fail
	cmp al, 127
;	je .check_character_fail
	jae .check_character_fail
		; note: with all characters >= 128 allowed,
		;  we get false positives in our sectors.
	cmp al, '.'
	je .check_character_fail
	cmp al, '/'
	je .check_character_fail
	cmp al, '\'
	je .check_character_fail
	cmp al, 'a'
	jb .check_character_pass
	cmp al, 'z'
	ja .check_character_pass
.check_character_fail:
	stc
	retn

.check_character_pass:
	clc
	retn

.check_loop:
	lodsb
.check_loop_differs:
	call .check_character
	jc .check_fail
.check_pass:
	loop .check_loop

	pop ax			; (discard si)
	sub si, 11		; -> at name

	call convert_name_to_asciz
				; si -> behind name
	pop cx
	sub cx, 11		; lessen the counter
	clc
	retn

.none:
	 add si, cx
	mov di, msg.foundname
	 push si
	mov si, msg.foundname_none
	mov cx, (msg.foundname_none_size + 1) >> 1
	rep movsw
	 pop si
	 xor cx, cx
	stc
	retn


		; INP:	si -> 11-byte blank-padded name
		;	msg.foundname -> (8+1+3+1)-byte buffer
		; OUT:	si -> behind 11-byte blank-padded name
		;	msg.foundname filled
		; CHG:	cx, di, ax
convert_name_to_asciz:
	mov di, msg.foundname
	mov cx, 8
	rep movsb		; copy over base name, si -> extension
	cmp byte [di - 8], 05h	; is it 05h ?
	jne @F			; no -->
	mov byte [di - 8], 0E5h	; yes, convert to 0E5h
@@:

	db __TEST_IMM8		; (skip dec)
@@:
	dec di			; decrement -> at previous trailing blank
	cmp byte [di - 1], 32	; trailing blank ?
	je @B			; yes -->

	mov al, '.'
	stosb			; store dot (if needed)
	mov cl, 3
	rep movsb		; copy over extension, si -> behind name

	db __TEST_IMM8		; (skip dec)
@@:
	dec di			; decrement -> at previous trailing blank
	cmp byte [di - 1], 32	; trailing blank ?
	je @B			; yes -->

	cmp byte [di - 1], '.'	; trailing dot ? (only occurs if all-blank ext)
	jne @F			; no -->
	dec di			; -> at the dot
@@:
	mov al, 0
	stosb			; store filename terminator
	retn


	align 4
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
