
%if 0

Loader test payload
 by C. Masloch, 2017

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

%endif


%include "lmacros2.mac"

	struc BS
bsJump:	resb 3
bsOEM:	resb 8
bsBPB:
	endstruc

	struc EBPB		;        BPB sec
bpbBytesPerSector:	resw 1	; offset 00h 0Bh
bpbSectorsPerCluster:	resb 1	; offset 02h 0Dh
bpbReservedSectors:	resw 1	; offset 03h 0Eh
bpbNumFATs:		resb 1	; offset 05h 10h
bpbNumRootDirEnts:	resw 1	; offset 06h 11h -- 0 for FAT32
bpbTotalSectors:	resw 1	; offset 08h 13h
bpbMediaID:		resb 1	; offset 0Ah 15h
bpbSectorsPerFAT:	resw 1	; offset 0Bh 16h -- 0 for FAT32
bpbCHSSectors:		resw 1	; offset 0Dh 18h
bpbCHSHeads:		resw 1	; offset 0Fh 1Ah
bpbHiddenSectors:	resd 1	; offset 11h 1Ch
bpbTotalSectorsLarge:	resd 1	; offset 15h 20h
bpbNew:				; offset 19h 24h

ebpbSectorsPerFATLarge:	resd 1	; offset 19h 24h
ebpbFSFlags:		resw 1	; offset 1Dh 28h
ebpbFSVersion:		resw 1	; offset 1Fh 2Ah
ebpbRootCluster:	resd 1	; offset 21h 2Ch
ebpbFSINFOSector:	resw 1	; offset 25h 30h
ebpbBackupSector:	resw 1	; offset 27h 32h
ebpbReserved:		resb 12	; offset 29h 34h
ebpbNew:			; offset 35h 40h
	endstruc

	struc BPBN		; ofs B16 S16 B32 S32
bpbnBootUnit:		resb 1	; 00h 19h 24h 35h 40h
			resb 1	; 01h 1Ah 25h 36h 41h
bpbnExtBPBSignature:	resb 1	; 02h 1Bh 26h 37h 42h -- 29h for valid BPBN
bpbnSerialNumber:	resd 1	; 03h 1Ch 27h 38h 43h
bpbnVolumeLabel:	resb 11	; 07h 20h 2Bh 3Ch 47h
bpbnFilesystemID:	resb 8	; 12h 2Bh 36h 47h 52h
	endstruc		; 1Ah 33h 3Eh 4Fh 5Ah

%ifndef _MAP
%elifempty _MAP
%else	; defined non-empty, str or non-str
	[map all _MAP]
%endif

	cpu 8086
	org 0
payload:
	align 32, nop

		; S0 +28
	pushf	; +26
	push ax	; +24
	push cs	; +22
	call .push_ip
.push_ip:
	pop ax
	sub ax, .push_ip
	push ax	; +20 IP

common_entrypoint:
	cmp word [cs:signature], 2638h
	je sig1_valid
	jmp sig_invalid

	align 64, nop
dos_exe_entrypoint:

		; S0 +28
	pushf	; +26
	push ax	; +24
	push cs	; +22
	call .push_ip
.push_ip:
	pop ax
	sub ax, .push_ip - dos_exe_entrypoint
	push ax	; +20 IP

	mov byte [cs:100h + loadmode], 1
	mov ax, cs
	add ax, 10h	; simulate kernel loading
	push ax
	mov ax, common_entrypoint
	push ax
	retf		; jump to cs + 10h : common_entrypoint


sig_invalid:
	call error
	db "Signature invalid.", 0

sig1_valid:
	push ds
	push bx
	mov bx, cs
	add bx, (signature2 -$$+0) >> 4
	mov ds, bx
	cmp word [(signature2 -$$+0) & 0Fh], 2638h
	pop bx
	pop ds
	jne sig_invalid
	jmp sig_valid

msg:
.error:	db "Test payload error: ", 0
.test:	db "Test payload loaded.", 13, 10, 0

.psp_and_size_before:	asciz "PSP at "
.psp_and_size_between:	asciz "h, size of memory block is "
.psp_and_size_after:	asciz "h paragraphs."

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

	align 2
loadmode:	dw 0		; 0 = loaded as boot payload, 1 = loaded in DOS

error:
	push cs
	pop ds
	mov si, msg.error
	call disp_msg
	pop si
	call disp_msg
	test byte [cs:loadmode], 1
	jz .bios

	mov ax, 4C01h
	int 21h

.bios:
	xor ax, ax
	int 16h
	int 19h

disp_msg_asciz:
	push ds
	push si
	push ax
	 push cs
	 pop ds
	mov si, dx
	call disp_msg
	pop ax
	pop si
	pop ds
	retn

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
	push dx
	push bp
	test byte [cs:loadmode], 1
	jz .bios

	mov dl, al
	mov ah, 02h
	int 21h
	jmp .common

.bios:
	mov ah, 0Eh
	mov bx, 7
	int 10h

.common:
	pop bp
	pop dx
	pop bx
	pop ax
@@:
	retn

sig_valid:
		; S0 +28
;	pushf	; +26
;	push ax	; +24
;	push cs	; +22
;	call .push_ip
;.push_ip:
;	pop ax
;	sub ax, .push_ip
;	push ax	; +20 IP
	sti
	cld
	push bx	; +18
	push cx	; +16
	push dx	; +14
	push si	; +12
	push di	; +10
	push bp	; +8
	mov ax, sp
	add ax, 20
	push ax	; +6 SP
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

listnames:
	test byte [cs:loadmode], 1
	jnz .skip

	mov bx, msg.names
	push ss
	pop ds
	lea si, [bp + bsBPB + ebpbNew + BPBN_size]
	mov cx, (512 - (bsBPB + ebpbNew + BPBN_size)) - 2
						; -2 = AA55h sig
	cmp word [bp + bsBPB + bpbSectorsPerFAT], 0
	je @F
	mov cx, (512 + (ebpbNew - bpbNew) - (bsBPB + ebpbNew + BPBN_size)) - 2
@@:
.nextname:
	call findname
	 lahf
	mov dx, [cs:bx]
	call disp_msg_asciz
	mov dx, msg.name_before
	call disp_msg_asciz
	 sahf
	 jc @F		; skip quote if no name -->
	 mov dx, msg.name_quote
	 call disp_msg_asciz
@@:
	mov dx, msg.foundname
	call disp_msg_asciz
	 sahf
	 jc @F		; skip quote if no name -->
	 mov dx, msg.name_quote
	 call disp_msg_asciz
@@:
	mov dx, msg.name_after
	call disp_msg_asciz
	 sahf
	 mov ax, 0
	 jc @F		; set to zero if no name -->
	 lea ax, [si - 11]	; -> name in buffer
@@:
	 mov word [cs:bx + 2], ax	; -> name in buffer, or 0
	add bx, 4
	cmp word [cs:bx], 0
	jne .nextname

.skip:

	push cs
	pop ds
	mov si, msg.test
	call disp_msg

	test byte [cs:loadmode], 1
	jz @F

	mov si, msg.psp_and_size_before
	call disp_msg
	mov ah, 51h
	int 21h
	mov ax, bx
	call disp_ax_hex
	mov si, msg.psp_and_size_between
	call disp_msg
	dec bx
	mov es, bx
	mov ax, word [es:3]
	call disp_ax_hex
	mov si, msg.psp_and_size_after
	call disp_msg

@@:
	int3

	test byte [cs:loadmode], 1
	jz .bios

	mov ax, 4C00h
	int 21h

.bios:
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
		; OUT:	(8+1+3+1)bytes[es:msg.foundname] = found name,
		;	 converted to 8.3 ASCIZ format,
		;	 "(None)" if none
		;	CY if no filename found,
		;	 si = INP:si + INP:cx
		;	 cx = 0
		;	NC if filename found,
		;	 ds:si -> byte behind the name, thus ds:(si-11)-> name
		;	 cx = number of bytes left
		; CHG:	di, ax
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
	 push ds
	push cs
	pop ds
	mov si, msg.foundname_none
	mov cx, (msg.foundname_none_size + 1) >> 1
	rep movsw
	 pop ds
	 pop si
	 xor cx, cx
	stc
	retn


		; INP:	ds:si -> 11-byte blank-padded name
		;	es:msg.foundname -> (8+1+3+1)-byte buffer
		; OUT:	ds:si -> behind 11-byte blank-padded name
		;	es:msg.foundname filled
		; CHG:	cx, di, ax
convert_name_to_asciz:
	mov di, msg.foundname
	mov cx, 8
	rep movsb		; copy over base name, si -> extension
	cmp byte [es:di - 8], 05h	; is it 05h ?
	jne @F			; no -->
	mov byte [es:di - 8], 0E5h	; yes, convert to 0E5h
@@:

	db __TEST_IMM8		; (skip dec)
@@:
	dec di			; decrement -> at previous trailing blank
	cmp byte [es:di - 1], 32	; trailing blank ?
	je @B			; yes -->

	mov al, '.'
	stosb			; store dot (if needed)
	mov cl, 3
	rep movsb		; copy over extension, si -> behind name

	db __TEST_IMM8		; (skip dec)
@@:
	dec di			; decrement -> at previous trailing blank
	cmp byte [es:di - 1], 32	; trailing blank ?
	je @B			; yes -->

	cmp byte [es:di - 1], '.'	; trailing dot ? (only occurs if all-blank ext)
	jne @F			; no -->
	dec di			; -> at the dot
@@:
	mov al, 0
	stosb			; store filename terminator
	retn


	align 4
table:
	dw  +0, "SS"
	dw  +8, "BP"
	dw  +6, "SP"
	dw +22, "CS"
	dw +20, "IP"
	dw +26, "FL"
	db -1, -1, 13,10
	dw  +4, "DS"
	dw +12, "SI"
	dw  +2, "ES"
	dw +10, "DI"
	db -1, -1, 13,10
	dw +24, "AX"
	dw +18, "BX"
	dw +16, "CX"
	dw +14, "DX"
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
