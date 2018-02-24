
%if 0

instsect.asm - install boot sectors. 2018 by C. Masloch

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

%endif


%include "lmacros2.mac"

numdef DEBUG0
numdef DEBUG1
numdef DEBUG2
numdef DEBUG3
numdef DEBUG4
numdef DEBUG5
%idefine d5 _d 5,
numdef VDD,		1	; try to load DEBXXVDD.DLL to use it for L and W sector commands


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

	struc DIRENTRY
deName:		resb 8
deExt:		resb 3
deAttrib:	resb 1
		resb 8
deClusterHigh:	resw 1
deTime:		resw 1
deDate:		resw 1
deClusterLow:	resw 1
deSize:		resd 1
	endstruc

ATTR_READONLY	equ 1
ATTR_HIDDEN	equ 2
ATTR_SYSTEM	equ 4
ATTR_VOLLABEL	equ 8
ATTR_DIRECTORY	equ 10h
ATTR_ARCHIVE	equ 20h

	struc LBAPACKET
lpSize:		resw 1
lpCount:	resw 1
lpBuffer:	resd 1
lpSector:	resq 1
	endstruc

	struc PARTINFO
piBoot:		resb 1
piStartCHS:	resb 3
piType:		resb 1
piEndCHS:	resb 3
piStart:	resd 1
piLength:	resd 1
	endstruc

ptEmpty:		equ 0
ptFAT12:		equ 1
ptFAT16_16BIT_CHS:	equ 4
ptExtendedCHS:		equ 5
ptFAT16_CHS:		equ 6
ptFAT32_CHS:		equ 0Bh
ptFAT32:		equ 0Ch
ptFAT16:		equ 0Eh
ptExtended:		equ 0Fh
ptLinux:		equ 83h
ptExtendedLinux:	equ 85h

%if _VDD
; standard BOPs for communication with DEBXXVDD on NT platforms
%macro RegisterModule 0.nolist
	db 0C4h, 0C4h, 58h, 0
	nop
%endmacro
%macro UnRegisterModule 0.nolist
	db 0C4h, 0C4h, 58h, 1
	nop
%endmacro
%macro DispatchCall 0.nolist
	db 0C4h, 0C4h, 58h, 2
	nop
%endmacro
%endif

	; This macro is used to generate byte or word access to specific
	; bits of a dword variable.
	; %1 = token: if "~", bit value will be negated after checking
	; %2 = instruction
	; %3 = variable, in the form "[address]" without size specification
	; %4 = bit value(s) to access
	; %5 = bool: disable word access warning, defaults to 0
	; If the value in %4 has bits set in different bytes so that
	; a single 8- or 16-bit instruction cannot access all the bits,
	; an error is displayed. This insures that the macro only has
	; to generate one instruction, as a 32-bit access on 16-bit
	; CPUs requires multiple instructions. This workaround code
	; needs to be written specifically then, or the flags have to
	; be re-ordered to allow the access.
%macro _opt 4-5.nolist 0
%push
%defstr %$adr %3
%strlen %$len %$adr
%substr %$tf %$adr 1
%substr %$tb %$adr %$len
%substr %$adr %$adr 2,-2
%deftok %$adr %$adr
%ifnidn %$tf,"["
 %error Invalid memory access syntax
%elifnidn %$tb,"]"
 %error Invalid memory access syntax
%elifn %4
 %error Bit value is zero! Check code.
%elifn (%4) & ~0FFh
	%2 byte [%$adr], %1(%4)
%elifn (%4) & ~0FF00h
	%2 byte [%$adr+1], %1((%4)>>8)
%elifn (%4) & ~0FF0000h
	%2 byte [%$adr+2], %1((%4)>>16)
%elifn (%4) & ~0FF000000h
	%2 byte [%$adr+3], %1((%4)>>24)
%elifn (%4) & ~0FFFFh
 %ifn %5
  %warning Macro generated word access
 %endif
	%2 word [%$adr], %1(%4)
%elifn (%4) & ~0FFFF00h
 %ifn %5
  %warning Macro generated word access
 %endif
	%2 word [%$adr+1], %1((%4)>>8)
%elifn (%4) & ~0FFFF0000h
 %ifn %5
  %warning Macro generated word access
 %endif
	%2 word [%$adr+2], %1((%4)>>16)
%else
 %error Unsupported macro usage, requires dword:
 %ifempty %1
  %error %2 dword [%$adr], %4
 %else
  %error %2 dword [%$adr], %1(%4)
 %endif
%endif
%pop
%endmacro

	; User forms for above macro.
	; %1 = variable, in the form "[address]" without size specification
	; %2 = bit value(s) to access
	; %3 = bool: disable word access warning, defaults to 0
	; testopt tests the specified bits (using a "test" instruction) and
	; leaves a meaningful result in ZF, as well as NC.
	; clropt clears the specified bits (using an "and" instruction with
	; the negated value) and leaves NC, but a random ZF.
	; setopt sets the specified bits (using an "or" instruction) and
	; leaves NC, NZ.
	; xoropt toggles the specified bits (using a "xor" instruction) and
	; leaves NC, but a random ZF.
%idefine testopt _opt ,test,
%idefine clropt _opt ~,and,
%idefine setopt _opt ,or,
%idefine xoropt _opt ,xor,


	[map all instsect.map]

	cpu 8086
	org 256
start:
			; This is a simple MS-DOS 1.x detection (8 Byte).
	mov ah, 4Dh		; the only function I found that doesn't need much setup or cleanup
	stc			; but that uses MS-DOS 2.x error reporting. clears CF (Int21.30 does not)
	int 21h
	jnc .dosgood		; it is MS-DOS 2.x+ or compatible -->
	retn			; it isn't so simply terminate
.dosgood:
	cld
	call initialise

	mov dx, i23
	mov ax, 2523h
	int 21h			; set Int23 so that we restore link/strategy on Ctrl-C as well
	mov dx, i24
	mov ax, 2524h
	int 21h			; set Int24 so all hard errors are changed to the soft error

; ...

	call restorestate
	mov ax, 4C00h
	int 21h


i24:
	mov al, 3			; always return fail, to handle the error as a soft one
	iret

i23:
	mov word [ cs:$ ], (__JMP_REL8|__REL16__(.return)<<8)	; don't reenter
	call restorestate
.return:
	stc				; always abort program (what default DOS handler also does)
	retf

		; Restore modified DOS data
		;
		; CHG:	-
restorestate:
	push ax
%if _VDD
		; Release the registered VDD.
	testopt [internalflags], ntpacket
	jz .novdd
	mov ax, word [hVdd]
	UnRegisterModule
.novdd:
%endif
	pop ax
	retn


	align 4
internalflags:	dd 0
oldpacket	equ	  1	; Int25/Int26 packet method available (L, W)
newpacket	equ	  2	; Int21.7305 packet method available (L, W)
ntpacket	equ	  4	; VDD registered and usable (L, W)
runningnt	equ   20000h	; running in NTVDM
hVdd:		dw 0


imsg:
%if _VDD
.vdd:		asciz "DEBXXVDD.DLL"
.dispatch:	asciz "Dispatch"
.init:		asciz "Init"
.mouse:		db "MOUSE",32,32,32		; Looks like a device name
.andy:		db "Andy Watson"		; I don't know him and why he's inside the NTVDM mouse driver
	endarea .andy
.ntdos:		db "Windows NT MS-DOS subsystem Mouse Driver"	; Int33.004D mouse driver copyright string (not ASCIZ)
	endarea .ntdos

		; INP:	-
		; OUT:	CY if not NTVDM
		;	NC if NTVDM
		;	ds = es = cs
		; CHG:	ax, bx, cx, dx, di, si, bp, es, ds
isnt:
		mov ax, 5802h			; Get UMB link state
		int 21h
		xor ah, ah
		push ax				; Save UMB link state
		mov ax, 5803h			; Set UMB link state:
		mov bx, 1			;  Add UMBs to memory chain
		int 21h
		mov ah, 52h
		mov bx, -1
		int 21h				; Get list of lists
		inc bx				; 0FFFFh ?
		jz .notnt			; invalid -->
		mov ax, word [es:bx-3]		; First MCB
		push cs
		pop es				; reset es
.loop:
		mov ds, ax			; ds = MCB
		inc ax				; Now segment of memory block itself
		xor dx, dx
		xor bx, bx
		cmp byte [bx], 'Z'		; End of MCB chain?
		jne .notlast
		inc dx
		jmp short .notchain
 .notlast:
		cmp byte [bx], 'M'		; Valid MCB chain?
		jne .error
 .notchain:
		mov cx, [bx+3]			; MCB size in paragraphs
				; ax = current memory block
				; cx = size of current memory block in paragraphs
				; dx = flag whether this is the last MCB
				; ds = current MCB (before memory block)
		cmp word [bx+1], 8		; MCB owner DOS?
		jne .notfound_1
		cmp word [bx+8], "SD"		; MCB name "SD"?
		jne .notfound_1
.loopsub:
		mov ds, ax			; SD sub-segment inside memory block
		inc ax
		dec cx
		mov bp, word [bx+3]		; Paragraphs 'til end of SD sub-segment
				; ax = current SD sub-segment
				; cx = paragraphs from SD sub-segment start (ax) to current memory block end
				; ds = current SD sub-MCB (like MCB, but for SD sub-segment)
				; bp = current SD sub-segment size in paragraphs
		cmp cx, bp
		jb .notfound_1			; Goes beyond memory block, invalid -->
		cmp byte [bx], 'Q'		; NTVDM type 51h sub-segment ?
		jne .notfound_2			; no -->
		mov si, 8			; Offset of device name (if SD device driver sub-segment)
		mov di, imsg.mouse
		push cx
		mov cx, si			; length of name
		repe cmpsb			; blank-padded device name "MOUSE" ?
		pop cx
		jne .notfound_2			;  Device name doesn't match, try next SD sub-segment
		mov ax, ds
		inc ax
		mov ds, ax			; Segment of SD sub-segment
				; ds = current SD sub-segment
		mov ax, bp			; Leave paragraph value in bp
		test ax, 0F000h			; Would *16 cause an overflow?
		jnz .notfound_3			;  Then too large -->
		push cx
		mov cl, 4
		shl ax, cl			; *16
		pop cx
				; ax = current SD sub-segment size in byte
.andy:
		mov di, imsg.andy
		push cx
		mov cx, imsg.andy_size
		call findstring			; String "Andy Watson"?
		pop cx
		jc .notfound_3
.ntdos:
		mov di, imsg.ntdos
		push cx
		mov cx, imsg.ntdos_size
		call findstring			; String "Windows NT MS-DOS subsystem Mouse Driver"?
		pop cx
		jnc .found			; (NC)
.notfound_3:
		mov ax, ds
.notfound_2:
		cmp cx, bp
		je .notfound_1			; End of SD memory block, get next MCB
		add ax, bp			; Address next SD sub-MCB
		sub cx, bp
		jmp short .loopsub		; Try next SD sub-segment
.notfound_1:
		add ax, cx			; Address next MCB
		test dx, dx			; Non-zero if 'Z' MCB
		jz .loop			; If not at end of MCB chain, try next
		; jmp short .notnt		;  Otherwise, not found
 .error:
 .notnt:
		stc
.found:
		push cs
		pop ds				; restore ds

		pop bx				; saved UMB link state
		mov ax, 5803h
		pushf
		int 21h				; Set UMB link state
		popf
		retn

findstring:
		xor si, si
.loop:
		push si
		add si, cx
		jc .notfound_c
		dec si				; The largest offset we need for this compare
		cmp ax, si
 .notfound_c:
		pop si
		jb .return			; Not found if at top of memory block -->
		push di
		push si
		push cx
		repe cmpsb			; String somewhere inside program?
		pop cx
		pop si
		pop di
		je .return			;  Yes, proceed --> (if ZR, NC)
		inc si				; Increase pointer by one
		jmp short .loop			;  Try next address
.return:
		retn
%endif


initialise:
		; Check DOS version
%if _VDD
	call isnt		; NTVDM ?
	jc .isnotnt		; no -->
	setopt [internalflags], runningnt
.isnotnt:
%endif

	mov ax, 3000h		; check DOS version
	int 21h
	xchg al, ah
	cmp ax, ver(3,31)	; MS-DOS version > 3.30 ?
	jb .notoldpacket	; no -->
	setopt [internalflags], oldpacket	; assume Int25/Int26 packet method available
.notoldpacket:
	push ax
	xor bx, bx		; preset to invalid value
	mov ax, 3306h
	int 21h
	or al, al		; invalid, DOS 1.x error -->
	jz .213306invalid
	cmp al, -1		; invalid
.213306invalid:
	pop ax
	je .useoldver
	test bx, bx		; 0.0 ?
	jz .useoldver		; assume invalid -->
	xchg ax, bx		; get version to ax
	xchg al, ah		; strange Microsoft version format
.useoldver:
	cmp ax, ver(7,01)	; MS-DOS version > 7.00 ?
	jb .notnewpacket	; no -->
	setopt [internalflags], newpacket| oldpacket	; assume both packet methods available
.notnewpacket:
%if _VDD
	testopt [internalflags], runningnt
	jz .novdd
	mov si, imsg.vdd	; ds:si-> ASCIZ VDD filename
	mov bx, imsg.dispatch	; ds:bx-> ASCIZ dispatching entry
	mov di, imsg.init	; es:di-> ASCIZ init entry
	clc			; !
	RegisterModule		; register VDD
	jc .novdd		; error ? -->
	mov word [hVdd], ax
	setopt [internalflags], ntpacket| oldpacket	; assume old packet method also available
.novdd:
%endif
	retn

