
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
		numdef METHOD, 2
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


disp_msg.loop:
	call disp_al
		; INP:	ds:si -> ASCIZ message
		; OUT:	ds:si -> past the terminating NUL byte
		;	al = 0
		; CHG:	bp
disp_msg:
	lodsb
	test al, al
	jnz .loop
	retn

disp_ax:
	call disp_al
	xchg al, ah

		; CHG:	bp
disp_al:
	push ax
	push bx
	mov ah, 0Eh
	mov bx, 7
	int 10h
	pop bx
	pop ax
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

	mov di, sp
	push cs
	pop ds
	mov si, table
%if _METHOD == 1
	mov cx, table.amount
loop_table:
	lodsb
	cbw
	xchg bx, ax
	mov al, 32
	call disp_al
	lodsw
	call disp_ax
	test bl, bl
	js @F
	mov al, '='
	call disp_al
	mov ax, [ss:di + bx]
	call disp_ax_hex
@@:
	loop loop_table
		; bx = FFFFh
%elif _METHOD == 2
loop_table:
	mov al, 32
	call disp_al
	lodsw
	mov cx, 0205h	; cl = 5, ch = 2
.loop_letter:
	mov dx, ax	; copy for remainder
	shr dx, cl	; shift right remainder by 5 bits
	and al, 1Fh	; isolate low 5 bits
	add al, '0'	; if a decit or A-F
	cmp al, 'A'	; is it an A-F ?
	jae .got	; yes -->
	cmp al, '9'	; is it a decit ?
	jbe .got	; yes -->
	mov bx, msg.xlation - ('0' + 10)
			; subtract '0' to undo add,
			;  and subtract 10 as a displacement
	xlatb		; and translate using the list tail
.got:
	call disp_al
	xchg ax, dx	; ax = shifted remainder, clobber dx
	dec ch		; loop for both letters
	jnz .loop_letter; jump after first letter -->
	cmp al, 0011_1110b
			; -2 or -1 in high 6 bits ?
	xchg bx, ax
	je .end
	ja @F		; yes, skip value display -->
	mov al, '='
	call disp_al	; display the equals sign
	mov ax, [ss:di + bx]
	call disp_ax_hex; display the hexit number
@@:
	jmp loop_table
.end:
		; bx = nonzero (= 0000_0000_0011_1110b)
%endif

	xor si, si
	mov cl, paras(32 * 4)
	call dump

	xor bx, bx		; bx = 0
	mov si, 7C00h - 32
	mov cl, paras(512 + 32)
	call dump

	int3

	xchg ax, cx
	int 16h
	int 19h


dump:
	mov di, cx
loop_dump:
	mov ax, di		; = initial loop counter
	sub ax, cx		; = initial loop counter minus current counter
				; can't be more than initial hence ah = 0
	push si
	test al, 15
	jnz @F
	mov si, msg.prompt
	call disp_msg
	; xor ax, ax		; already ah == 0 because ax was <= initial counter
	int 16h
	; mov si, msg.prompt_delete
	call disp_msg
@@:
	pop ax
	push cx
	mov si, ax
	test bx, bx
	jz @F
	shr ax, 1
	shr ax, 1		; convert byte offset to IVT interrupt number
	call disp_al_hex	; display interrupt number
	jmp @FF
@@:
	call disp_ax_hex	; display byte offset
@@:
	mov ax, 2020h
	call disp_ax
	push si
	mov cl, 16		; counter always < 256, so ch already == 0
.loop_byte_number:
	test bx, bx
	jz @F
	lodsw
	push ax
	lodsw
	call disp_ax_hex
	mov al, ':'
	call disp_al
	pop ax
	call disp_ax_hex
	dec cx
	dec cx
	dec cx
	jmp .dash
@@:
	lodsb
	call disp_al_hex
.dash:
	cmp cl, 9
	mov al, 32
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
	inc ax
	cmp al, 32
	jg @F
	mov al, '.' + 1
@@:
	dec ax
	call disp_al
	loop .loop_byte_text
	mov ax, 13 + (10 << 8)
	call disp_ax
	pop cx
	loop loop_dump
	retn


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

msg:
.prompt:	asciz "[more]"
.prompt_length equ $ - 1 - .prompt
.prompt_delete:	db 13
		times .prompt_length db 32
		db 13
		db 0
%if _METHOD == 2
.xlation:
	db "ILPSX", 13, 10
 %if $ - .xlation > 'A' - ('0' + 10)
  %error Translation table too long!
 %endif
%endif


%imacro item 2.nolist
 %if _METHOD == 1
	db %1, %2
 %elif _METHOD == 2
 %strcat %%list "0123456789ILPSX",`\r\n`,"ABCDEF"
 %substr %%testpoint %%list 'A' - '0' + 1
 %ifnidn %%testpoint, 'A'
  %fatal Translation list wrong!
 %endif
 %strlen %%listlength %%list
 %assign %%encoded (%1 & 0011_1111b) << 10
 %assign %%jj 0
 %rep 2
  %substr %%toencode %2 %%jj + 1
  %assign %%ii 0
  %rep %%listlength
   %substr %%point %%list %%ii + 1
   %ifidn %%point, %%toencode
    %exitrep
   %else
    %assign %%ii %%ii + 1
   %endif
  %endrep
  %if %%ii == %%listlength
   %fatal Unencodeable point %%toencode in %2
  %endif
  %assign %%encoded %%encoded | (%%ii << (%%jj * 5))
  %assign %%jj %%jj + 1
 %endrep
	dw %%encoded
 %else
  %fatal Unknown method selected: _METHOD
 %endif
%endmacro

%if _METHOD == 2
unaligned:
	align 2
aligned:
 %if unaligned != aligned
  %warning Alignment byte emitted
 %endif
%endif
table:
.:	item  +0, "SS"
	item  +6, "BP"
	item  +4, "SP"
	item +22, "CS"
	item +20, "IP"
	item +26, "FL"
	item -1, `\r\n`
	item  +2, "DS"
	item +10, "SI"
	item +18, "ES"
	item  +8, "DI"
	item -1, `\r\n`
	item +24, "AX"
	item +16, "BX"
	item +14, "CX"
	item +12, "DX"
	item -1, `\r\n`
	item +28, "S0"
	item +30, "S1"
	item +32, "S2"
	item +34, "S3"
	item +36, "S4"
	item +38, "S5"
	item +40, "S6"
	item +42, "S7"
	item -1, `\r\n`
	item +44, "S8"
	item +46, "S9"
	item +48, "SA"
	item +50, "SB"
	item +52, "SC"
	item +54, "SD"
	item +56, "SE"
	item +58, "SF"
 %if _METHOD == 1
	item -1, `\r\n`
 %elif _METHOD == 2
	item -2, `\r\n`
 %endif
%if _METHOD == 1
.end:
.amount equ (.end - .) / 3
%endif

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
