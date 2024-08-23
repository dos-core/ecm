
%if 0

Loader test
 by E. C. Masloch, 2024

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

%endif


%include "lmacros2.mac"


		numdef FAT12, 0
		numdef FAT16, 0
		numdef FAT32, 0
		numdef NO_LIMIT, 0

%if (!!_FAT12 + !!_FAT16 + !!_FAT32) > 1
 %error Must select at most one file system type
%endif


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
	org 7C00h
start:
	jmp strict short skip_bpb
	nop
	fill 8, '_', db "lDOSTEST"

%if _FAT12
	times bsBPB + bpbNew + bpbnFilesystemID - ($ - $$) db 0
	fill 8, 32, db "FAT12"
%elif _FAT16
	times bsBPB + bpbNew + bpbnFilesystemID - ($ - $$) db 0
	fill 8, 32, db "FAT16"
%elif _FAT32
	times bsBPB + ebpbNew + bpbnFilesystemID - ($ - $$) db 0
	fill 8, 32, db "FAT32"
%endif
	times bsBPB + ebpbNew + BPBN_size - ($ - $$) db 0

skip_bpb:
		; S0 +28
	pushf	; +26
	push ax	; +24
	push cs	; +22
	call .push_ip
.push_ip:
	pop ax
	sub ax, .push_ip - start
	push ax	; +20 IP
	jmp 0:common_entrypoint


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

disp_msg_length:
	push cx
	jcxz .ret
.loop:
	lodsb
	call disp_al
	loop .loop
.ret:
	pop cx
	retn


common_entrypoint:
	push es	; +18 ES
	push bx	; +16 BX
	sti
	cld
	push cx	; +14
	push dx	; +12
	push si	; +10
	push di	; +8
	push bp	; +6
	mov ax, sp
	add ax, 22
	push ax	; +4 SP
	push ds	; +2
	push ss	; +0

	mov si, sp
	 push ss
	 pop ds
	mov di, table
	 push cs
	 pop es
loop_table:
	xor bx, bx
	mov bl, [es:di]
	inc di
	mov al, 32
	call disp_al
	mov ax, [es:di]
	call disp_al
	xchg al, ah
	call disp_al
	cmp bl, -1
	je @F
	mov al, '='
	call disp_al
	mov ax, [si + bx]
	call disp_ax_hex
@@:
	scasw
	cmp di, table.end
	jb loop_table

	push cs
	pop ds
	mov si, 7C00h - 32
	mov cx, paras(512 + 32)
loop_dump:
	mov ax, cx
	neg ax
	add ax, paras(512 + 32)
	test al, 15
	jnz @F
	mov dx, msg.prompt
	call disp_msg_asciz
	xor ax, ax
	int 16h
	mov dx, msg.prompt_delete
	call disp_msg_asciz
@@:
	mov ax, si
	call disp_ax_hex
	mov al, 32
	call disp_al
	call disp_al
	push cx
	push si
	mov cx, 16
.loop_byte_number:
	lodsb
	call disp_al_hex
	mov al, 32
	cmp cl, 9
	jne @F
	mov al, '-'
@@:
	call disp_al
	loop .loop_byte_number
	pop si
	mov cl, 16
	call disp_al
.loop_byte_text:
	lodsb
	cmp al, 32
	jb .replace
	cmp al, 7Fh
	jb @F
.replace:
	mov al, '.'
@@:
	call disp_al
	loop .loop_byte_text
	mov al, 13
	call disp_al
	mov al, 10
	call disp_al
	pop cx
	loop loop_dump

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


	align 4
table:
	db  +0, "SS"
	db  +6, "BP"
	db  +4, "SP"
	db +22, "CS"
	db +20, "IP"
	db +26, "FL"
	db -1, 13,10
	db  +2, "DS"
	db +10, "SI"
	db +18, "ES"
	db  +8, "DI"
	db -1, 13,10
	db +24, "AX"
	db +16, "BX"
	db +14, "CX"
	db +12, "DX"
	db -1, 13,10
	db +28, "S0"
	db +30, "S1"
	db +32, "S2"
	db +34, "S3"
	db +36, "S4"
	db +38, "S5"
	db +40, "S6"
	db +42, "S7"
	db -1, 13,10
	db +44, "S8"
	db +46, "S9"
	db +48, "SA"
	db +50, "SB"
	db +52, "SC"
	db +54, "SD"
	db +56, "SE"
	db +58, "SF"
	db -1, 13,10
.end:

msg:
.prompt:	asciz "[more]"
.prompt_length equ $ - 1 - .prompt
.prompt_delete:	db 13
		times .prompt_length db 32
		db 13
		db 0

%if !_NO_LIMIT
available:
        _fill 508,38,start

signatures:
        dw 0
; 2-byte magic bootsector signature
        dw 0AA55h

%assign num signatures-available
%define name TEST
%if _FAT12
 %define name TEST FAT12
%elif _FAT16
 %define name TEST FAT16
%elif _FAT32
 %define name TEST FAT32
%endif
%warning name: num bytes still available.
%endif
