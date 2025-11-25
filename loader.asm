
%if 0

lDOS/lDebug extensions loader
 by E. C. Masloch, 2025

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

%endif

%include "lmacros3.mac"
%ixdefine d4 comment

	numdef PADDING, 0

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

	struc LOADSTACKVARS, -10h
lsvFirstCluster:	resd 1
lsvFATSector:		resd 1
lsvFATSeg:		resw 1
lsvLoadSeg:		resw 1
lsvDataStart:		resd 1
	endstruc

lsvclSignature		equ "CL"
lsvclBufferLength	equ 256

	struc LOADDATA, LOADSTACKVARS - 10h
ldMemoryTop:	resw 1
ldLoadTop:	resw 1
ldSectorSeg:	resw 1
ldFATType:	resb 1
ldHasLBA:	resb 1
ldClusterSize:	resw 1
ldParaPerSector:resw 1
ldLoadingSeg:		; word
ldQueryPatchValue:	; word
lsvCommandLine:		; word
.start:		equ $ - lsvclBufferLength
.signature:	resw 1
ldLoadUntilSeg:		; word
lsvExtra:		; word
.partition:	resb 1	; byte
.flags:		resb 1	; byte
	endstruc

ldhlfLBA:		equ 1
ldhlfForceSingleSector:	equ 2
ldhlfPreserveLoader	equ 4

lsvefNoDataStart	equ 1
lsvefPartitionNumber	equ 2
lsvefPreserveLoader	equ 4

%if lsvefPreserveLoader	!= ldhlfPreserveLoader
 %error Unexpected flag values
%endif

	struc LOADCMDLINE, LOADDATA - lsvclBufferLength
ldCommandLine:
.start:		resb lsvclBufferLength
	endstruc

	struc LOADMULTIVARS, LOADCMDLINE - 8
ldmCluster:	resd 1
ldmSector:	resd 1
	endstruc

	struc LOADERIMAGEIDENT
liiSignature:		resb 4		; "NLDR"
liiVersion:		resb 2		; "00"
liiChecksum:		resw 1		; word sum of first 8 words = 0
liiAmountParagraphs:	resw 1
liiReserved:		resw 3
liiEntryQuerySize:	resw 1		; 0 if not supported
		; INP:	cs => NLDR image ident
		;	ip = this word field content
		;	ax = 60h
		; OUT:	ax => behind memory requested (should be >= 60h)
		; CHG:	es, ds, di, si, bx, cx, dx
		; STT:	far called, UP, EI
liiEntryRelocate:	resw 1		; 0 if not supported
		; INP:	cs => NLDR image ident
		;	ip = this word field content
		; OUT:	ax => relocated NLDR segment (usually 60h)
		; CHG:	es, ds, di, si, bx, cx, dx
		; STT:	far called, UP, EI
liiEntryDebug:		resw 1		; 0 if not supported
		; INP:	es = ds = cs = ss => relocated NLDR
		;	ip = this word field content
		;	sp = next word field content
		; STT:	running as debuggee, UP, EI
liiStackPointer:	resw 1
	endstruc

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


%ifndef _MAP
%elifempty _MAP
%else	; defined non-empty, str or non-str
	[map all _MAP]
%endif

	defaulting


LOADSEG equ 200h
ALLOCATION equ (fromkib(kib(endallocation - $$)))

	cpu 8086
	bits 16
	org 0
imageident:

	istruc LOADERIMAGEIDENT
at liiSignature
	db "NLDR00"
at liiAmountParagraphs
	dw paras(ALLOCATION)
at liiEntryQuerySize
	dw query
at liiEntryRelocate
	dw reloc
at liiEntryDebug
	dw debug
at liiStackPointer
	dw 0
	iend

	times 32 - ($ - $$) db 0

start:		; ip = 32
	jmp relocatedown

query:
	cmp ax, 60h
	je @F
	call error
	db "Unexpected query segment address."
@@:
	mov ax, 60h + paras(endallocation - $$)
	retf

reloc:
	call unhook_and_place_at_600
	mov ax, 60h
	retf

debug:
	mov si, msg.debug
	call disp_error
	int 16h
	int 19h


main:

selectboot:
	mov al, [bp + ldFATType]
	mov bx, ldboot12
	cmp al, 12
	je @F
	mov bx, ldboot16
	cmp al, 16
	je @F
	mov bx, ldboot32
	cmp al, 32
	je @F
	call error
	db "Unknown FAT type passed by initial loader."
@@:

initbpb:
	push cs
	pop es
	lea di, [bx + bsBPB]
	push ss
	pop ds
	lea si, [bp + bsBPB]
	mov cx, bpbNew
	rep movsb
	cmp al, 32
	jne .not32
	mov cx, ebpbNew - bpbNew
	rep movsb

.not32:
	lea si, [bp + bsBPB + ebpbNew]
	mov cx, BPBN_size
	rep movsb

patchname:
	lea cx, [bx + 512]
	sub cx, di

	 push cx
	 push di

	push cs
	pop ds
	mov si, msg.nametemplate

	xchg ax, dx
	lodsb

.scanloop:
	repne scasb
	je .scancheck
	call error
	db "Filename template not found."

.scancheck:
	push cx
	push si
	push di
	mov cx, 7 + 3
	repe cmpsb
	pop di
	pop si
	pop cx
	jne .scanloop

.scandone:
	dec di
	mov si, msg.name
	mov cx, 8 + 3
	rep movsb

patchfsiboot:
	cmp dl, 32
	jne .done

	pop di
	pop cx
	push cx
	push di

	push cs
	pop ds
	mov si, fsibootpattern
	lodsb

.scanloop:
	repne scasb
	je .scancheck
	call error
	db "FSIBOOT loaded check not found."

.scancheck:
	push cx
	push si
	push di
	mov cl, [es:di - 1 + fsibootpattern.wildcard1]
	mov [si - 1 + fsibootpattern.wildcard1], cl
	mov cl, [es:di - 1 + fsibootpattern.wildcard2]
	mov [si - 1 + fsibootpattern.wildcard2], cl
	mov cx, fsibootpattern.size - 1
	repe cmpsb
	pop di
	pop si
	pop cx
	jne .scanloop

.scandone:
	mov byte [es:di - 1 + fsibootpattern.patch], __JMP_REL8

.done:

patchjump:
	pop di
	pop cx

	push cs
	pop ds
	mov si, jumppattern
	lodsb

.scanloop:
	repne scasb
	je .scancheck
	call error
	db "Jump instruction not found."

.scancheck:
	push cx
	push si
	push di
	mov cx, jumppattern.size - 1
	repe cmpsb
	pop di
	pop si
	pop cx
	jne .scanloop

.scandone:
	mov word [es:di - 1 + 1], prefixloadedentry
	lea ax, [di - 1 + 3]
	mov word [prefixloadedsegment], ax
	push bx				; -> boot sector to load


init_imageident:
	push cs
	pop ds
	mov si, imageident
	mov cx, 8
	xor dx, dx
.loop:
	lodsw
	add dx, ax
	loop .loop

	neg dx
	mov word [imageident + liiChecksum], dx	; set image ident checksum


relocatetop:
	int 12h
	mov cl, 6
	shl ax, cl

	push ax
	push ds
	xor si, si
	xchg dx, ax
	mov ds, si
	lds si, [4 * 2Fh]
	add si, 3
	lodsb
	cmp al, 'R'
	jne .no_rpl
	lodsb
	cmp al, 'P'
	jne .no_rpl
	lodsb
	cmp al, 'L'
	jne .no_rpl
	mov ax, 4A06h
	int 2Fh
.no_rpl:
	xchg ax, dx
	pop ds
	pop dx

	cmp ax, dx
	je .no_error_rpl
		; in case RPL is present, error out (for now)

		; notes for +RPL installation:
		; 1. Allocate enough memory for our MCB + an PSP + our image + the last and the RPL MCB
		; 2. Create the RPL's MCB + a last MCB
		; 3. Relocate, initialise PSP
		; 4. Hook Int2F as RPLOADER to report DOS our new size

%if 0
	mov dx, imsg.rpl_detected
	jmp .putsz_error
%else
	call error
	db "RPL detected! Currently unsupported."
%endif

.no_error_rpl:
d4	call init_d4message
d4	asciz "Loader past RPL detection",13,10

	mov bx, ax

@@:					; bx => behind usable memory
%if 0
	mov ah, 0C1h
	stc
	int 15h				; BIOS, do you have an EBDA?
	mov ax, es
	jnc .ebda			; segment in ax -->
					; I don't believe you, let's check
%endif	; Enabling this would enable the BIOS to return an EBDA even if it isn't
	; noted at 40h:0Eh, which would be useless because we have to relocate it.

	xor dx, dx			; initialise dx to zero if no EBDA
	mov ax, 40h
	mov es, ax
	mov ax, word [ es:0Eh ]		; EBDA segment (unless zero) or LPT4 base I/O address (200h..3FCh)
	cmp ax, 400h
	jb .noebda			; -->
.ebda:
d4	call init_d4message
d4	asciz "EBDA detected",13,10

	inc byte [cs:init_boot_ebdaflag]
	cmp ax, bx
	;jb init_booterror.soft		; uhh, the EBDA is inside our memory?
	;ja init_booterror.soft		; EBDA higher than top of memory. This is just as unexpected.
	je @F
%if 0
	mov dx, imsg.boot_ebda_unexpected
	jmp .putsz_error
%else
	call error
	db "EBDA at unexpected position."
%endif

@@:
	mov ds, ax
	xor dx, dx
	mov dl, byte [ 0 ]		; EBDA size in KiB
	mov cl, 6
	shl dx, cl			; *64, to paragraphs
	mov word [cs:init_boot_ebdasize], dx
	mov word [cs:init_boot_ebdasource], ax
d4	jmp @F
.noebda:
d4	call init_d4message
d4	asciz "No EBDA detected",13,10
@@:


clearstack:
	push cs
	pop es
	mov di, stack
	mov cx, words(stack.top - stack)
	mov ax, "^^"
	rep stosw


relocstack:
	pop ax				; -> boot sector to load

	push ss
	pop ds
	push cs
	pop es
	mov di, stack.top
	lea si, [bp + LOADDATA]
	push cs
	cli
	pop ss
	mov sp, di			; -> stack in code segment
	sti
	mov cx, words(-LOADDATA + 512 + ebpbNew - bpbNew)
	rep movsw

	lframe none
	lenter
	lvar word, ldboot
	 push ax
	lvar word, target

	mov cx, bx
	add cx, [cs:init_boot_ebdasize]
	sub cx, paras(ALLOCATION)
	 push cx		; push into ?target

	cmp byte [cs:init_boot_ebdaflag], 0
	jz .reloc_memtop_no_ebda
	sub cx, word [cs:init_boot_ebdasize]
	mov ax, word [cs:init_boot_ebdasource]
	mov dx, cx
	mov word [cs:init_boot_ebdadest], cx
	mov cx, word [cs:init_boot_ebdasize]
	cli
	call init_movp
	or byte [cs:init_boot_ebdaflag], 2
	mov ax, 40h
	mov es, ax
	mov word [es:0Eh], dx	; relocate EBDA

d4	call init_d4message
d4	asciz "EBDA relocated",13,10

	jmp @F

.reloc_memtop_no_ebda:
	mov dx, cx
@@:
	mov cl, 6
	shr dx, cl
	mov ax, 40h
	mov es, ax
	mov word [ cs:init_boot_new_memsizekib ], dx
	xchg word [es:13h], dx
	mov word [ cs:init_boot_old_memsizekib ], dx
	sti
d4	call init_d4message
d4	asciz "Memory top relocated",13,10

	mov es, word [bp + ?target]
	mov di, stack.padding
	mov cx, words(ALLOCATION - (stack.padding - $$))
	mov ax, 2626h
	rep stosw
	xor di, di
	push cs
	pop ds
	xor si, si
	mov cx, words(endallocation - $$)
	rep movsw
	push es
	call retfinstruction
	push es
	pop ss
	nop

	push cs
	pop ds
	not byte [reserved]

	mov si, word [prefixloadedsegment]
	mov word [si], cs	; patch jump instruction

	mov si, [bp + ?ldboot]	; -> loader to run
	xor ax, ax
	mov es, ax
	mov di, 7C00h		; -> boot sector destination
	mov cx, words(1024)	; (include FSIBOOT if FAT32)
	rep movsw		; place sector
	mov dl, byte [stack.bootsector + bsBPB + ebpbNew + bpbnBootUnit]
				; dl = load unit
	mov ds, ax
	mov si, 600h		; -> expected MBR relocated
	mov di, si		; -> same
	mov cx, words(16)
	rep stosw		; invalidate expected partition table entry
	mov si, 18h * 4
	push cs
	pop es
	mov di, i18.next

	cli
	movsw
	movsw
	mov word [si - 4], i18
	mov word [si - 2], cs
	mov di, i19.next
	movsw
	movsw
	mov word [si - 4], i19
	mov word [si - 2], cs
	not byte [cs:intercepted]
	mov ss, ax
	mov sp, 7C00h
	sti
	jmp 0:7C00h		; run boot sector loader

prefixloadedentry:
	mov cx, word [bp + lsvLoadSeg]
	cmp cx, LOADSEG + paras(4096)
	jae @F
	call error
	db "Load end segment in LSV too low."
@@:
	cmp cx, LOADSEG + paras(24 * 1024)
	jbe @F
	mov cx, LOADSEG + paras(24 * 1024)
@@:
	mov ax, LOADSEG
	sub cx, ax
.scanloop:
	mov es, ax
	xor di, di
	push cx
	 push cs
	 pop ds
	mov si, msg.loadsupportsignature
	mov cx, msg.loadsupportsignature.size
	repe cmpsb
	pop cx
	je .foundsignature
	inc ax
	loop .scanloop
	call error
	db "Loader support signature not found."

.foundsignature:
	test byte [es:di], -1
	jz .noflag
	call error
	db "Loader support unknown flag set."

.noflag:
	mov ax, LOADSEG
	mov es, ax
	mov di, 400h
	mov si, entrypattern
	mov cx, entrypattern.size
	repe cmpsb
	je .foundentry
	call error
	db "Extended lsvExtra entry not found."

.foundentry:
	xor ax, ax		; pass ax as zero
	lea sp, [bp + lsvCommandLine + 4]
	push ax			; push into lsvExtra
	push ax			; push into lsvCommandLine
	setopt [bp + lsvExtra.flags], lsvefPreserveLoader
				; set flag
	cli			; pass control flags as UP, DI
	jmp LOADSEG:400h + entrypattern.size


entrypattern:
.:		; Expected at 200h:400h to allow passing a
		;  nonzero lsvExtra to the initial loader.
		;  This code is skipped if found.
	cli
	cld
	xor ax, ax
	push ax
	mov word [bp + lsvExtra], ax
	push ax
.size equ $ - .

jumppattern:
.:		; Expected in boot sector loader to transfer
		;  control to the loaded kernel prefix at
		;  200h:0 (entered at 200h:400h). This code
		;  is patched to jump to our resident entry.
	jmp LOADSEG:400h
.size equ $ - .

fsibootpattern:
.:		; Expected in FAT32 first stage to check
		;  whether FSIBOOT (second stage) is already
		;  loaded. Patched to assume already loaded.
	cmp ax, 1024 >> 5
.patch equ $ - .
	jae .
.wildcard1 equ $ - 1 - .
	cwd
	mov ax, [bp + bsBPB + ebpbFSINFOSector]
	test ax, ax
	jz @F
	cmp ax, [bp + bsBPB + bpbReservedSectors]
@@:
	jae .
.wildcard2 equ $ - 1 - .
.size equ $ - .


		; Move paragraphs
		;
		; INP:	ax:0-> source
		;	dx:0-> destination
		;	cx = number of paragraphs
		; CHG:	-
		; Note:	Doesn't work correctly on HMA; doesn't always wrap to LMA either.
		;	Do not provide a wrapped/HMA source or destination!
init_movp:
	push cx
	push ds
	push si
	push es
	push di

	cmp ax, dx		; source above destination ?
	ja .up			; yes, move up (forwards) -->
	je .return		; same, no need to move -->
	push ax
	add ax, cx		; (expected not to carry)
	cmp ax, dx		; end of source is above destination ?
	pop ax
	ja .down		; yes, move from top down -->
	; Here, the end of source is below-or-equal the destination,
	;  so they do not overlap. In this case we prefer moving up.

.up:
	push ax
	push dx
.uploop:
	mov ds, ax
	mov es, dx
	xor di, di
	xor si, si		; -> start of segment
	sub cx, 1000h		; 64 KiB left ?
	jbe .uplast		; no -->
	push cx
	mov cx, 10000h /2
	rep movsw		; move 64 KiB
	pop cx
	add ax, 1000h
	add dx, 1000h		; -> next segment
	jmp short .uploop	; proceed for more -->
.uplast:
	add cx, 1000h		; restore counter
	shl cx, 1
	shl cx, 1
	shl cx, 1		; *8, paragraphs to words
	rep movsw		; move last part
	pop dx
	pop ax
	jmp short .return

.down:
	std			; _AMD_ERRATUM_109_WORKAROUND as below
.dnloop:
	sub cx, 1000h		; 64 KiB left ?
	jbe .dnlast		; no -->
	push ax
	push dx
	add ax, cx
	add dx, cx
	mov ds, ax		; -> 64 KiB not yet moved
	mov es, dx
	pop dx
	pop ax
	mov di, -2
	mov si, di		; moved from last word down
	push cx
	mov cx, 10000h /2
	rep movsw		; move 64 KiB
	pop cx
	jmp short .dnloop	; proceed for more -->
.dnlast:
	add cx, 1000h		; restore counter
	shl cx, 1
	shl cx, 1
	shl cx, 1		; *8, paragraphs to words
	mov di, cx
	dec di
	shl di, 1		; words to offset, -> last word
	mov si, di
	mov ds, ax
	mov es, dx		; first segment correct


	numdef AMD_ERRATUM_109_WORKAROUND, 1
%if 0

Jack R. Ellis pointed out this erratum:

Quoting from https://www.amd.com/system/files/TechDocs/25759.pdf page 69:

109   Certain Reverse REP MOVS May Produce Unpredictable Behavior

Description

In certain situations a REP MOVS instruction may lead to
incorrect results. An incorrect address size, data size
or source operand segment may be used or a succeeding
instruction may be skipped. This may occur under the
following conditions:

* EFLAGS.DF=1 (the string is being moved in the reverse direction).

* The number of items being moved (RCX) is between 1 and 20.

* The REP MOVS instruction is preceded by some microcoded instruction
  that has not completely retired by the time the REP MOVS begins
  execution. The set of such instructions includes BOUND, CLI, LDS,
  LES, LFS, LGS, LSS, IDIV, and most microcoded x87 instructions.

Potential Effect on System

Incorrect results may be produced or the system may hang.

Suggested Workaround

Contact your AMD representative for information on a BIOS update.

%endif

%if _AMD_ERRATUM_109_WORKAROUND
	jcxz @FF
	cmp cx, 20
	ja @FF
@@:
	movsw
	loop @B
@@:
%endif
	rep movsw		; move first part
	cld
.return:
	pop di
	pop es
	pop si
	pop ds
	pop cx
	retn


unhook_and_place_at_600:
	push cs
	pop ds
	rol byte [intercepted], 1
	jnc @F
	xor ax, ax
	mov es, ax
	mov di, 18h * 4
	mov si, i18.next

	cli
	movsw
	movsw
	mov si, i19.next
	movsw
	movsw
	not byte [intercepted]
	sti
@@:
	rol byte [reserved], 1
	jnc .notreserved

	mov ax, 60h
	mov es, ax
	xor di, di
	xor si, si
	mov cx, words(endallocation - $$)
	rep movsw
	mov dx, cs
	push es
	call retfinstruction

	mov cx, ss
	cmp cx, dx
	jne @F
	mov ss, ax
	nop
@@:

	mov ax, 40h
	mov es, ax

	test byte [cs:init_boot_ebdaflag], 2
	jz @F

	cli
	mov dx, [cs:init_boot_ebdasource]
	mov ax, [cs:init_boot_ebdadest]
	mov cx, [cs:init_boot_ebdasize]
	call init_movp

	mov word [es:0Eh], dx
@@:

	mov dx, [cs:init_boot_old_memsizekib]
	test dx, dx
	jz @F
	mov word [es:13h], dx
@@:
	push cs
	pop ds
	not byte [reserved]
	sti

.notreserved:
	retn


error:
	call unhook_and_place_at_600

	mov si, msg.error
	call disp_error		; display "Load error: "
	pop si			; -> ASCII string terminated by dot
	call disp_error		; display up to before dot
	dec si			; -> point back at dot to return after display
	call disp_error.loop	; display the dot, ah = 0
	int3
	int 16h
	int 19h


disp_error.loop:
	mov ah, 0Eh
	mov bx, 7		; bh = page 0
	push bp
	int 10h
	pop bp
disp_error:
	lodsb
	cmp al, '.'
	jne .loop
	cbw			; al = 2Eh '.' so ah here becomes zero
	retn

retfinstruction:
	retf


i18:
	mov ax, cs
	mov ss, ax
	mov sp, stack.top
	call error
	db "Interrupt 18h called."
	align 2, db 0
.next:
	dd 0

i19:
	mov ax, cs
	mov ss, ax
	mov sp, stack.top
	call error
	db "Interrupt 19h called."
	align 2, db 0
.next:
	dd 0

msg:
.debug:	db "Hello world!",13,10,"."
.error:	db "Loader error: ."
.name:	fill 8, 32, db "LDDEBUGU"
	fill 3, 32, db "COM"
.nametemplate:
	fill 8, 32, db "FILENAME"
	fill 3, 32, db "EXT"

	align 2
.loadsupportsignature:
	db "LOAD","ERSU","PPOR","T00"	; signature and version
.loadsupportsignature.size equ $ - .loadsupportsignature

	align 16
		; The following are used for loading the debugger.
		; Expectation:
		; * lDOS compatibility
		; * jmp 200h:400h
		; * FILENAME.EXT stored as filename
		; * FAT32 loader uses FSIBOOT
ldboot12:
.:
	incbin "ldboot12.bin"
%if ($ - .) != 512
 %error Unexpected FAT12 boot sector loader size
%endif
ldboot16:
.:
	incbin "ldboot16.bin"
%if ($ - .) != 512
 %error Unexpected FAT16 boot sector loader size
%endif
ldboot32:
.:
	incbin "ldboot32.bin"
%if ($ - .) != 1024
 %error Unexpected FAT32 boot sector loader size
%endif

%if 0
payload:
	incbin "ldpaylod.bin"
	align 16
.end:
%endif

	align 2, db 0
prefixloadedsegment:	dw 0

init_boot_new_memsizekib:	dw 0
init_boot_old_memsizekib:	dw 0

init_boot_ebdasize:	dw 0
init_boot_ebdasource:	dw 0
init_boot_ebdadest:	dw 0
init_boot_ebdaflag:	db 0

intercepted:		db 0
reserved:		db 0

relocatedown:
	mov ax, cs
	cmp ax, 60h
	jae .do
	call error		; shouldn't happen
	db "Too low load."

.do:
	mov dx, 60h
	mov es, dx		; => destination (61h)
	mov ds, ax		; => cs source

	push dx
	call .relocate
.done:
	jmp main

%if _PADDING
 %if ($ - $$) > _PADDING
  %warning No padding needed
 %else
	times _PADDING - ($ - $$) db 0
 %endif
%endif

.relocate:
	xor di, di
	xor si, si
	mov cx, words(end - $$)	; = amount words

; Following part must be in the last progbits paragraph.
	align 16, nop
.relocator:
	rep movsw
	retf
.relocator_size equ $ - .relocator
%if .relocator_size > 16
 %error Too large relocator
%endif
%if ((.relocator - $$) & ~15) != (($ - $$) & ~15)
 %error Placement of relocator is wrong
%endif

end:

absolute $
	alignb 16
stack:
	resb 512
.top:
	resb - LOADDATA
.bootsector:
	resb 512 + (ebpbNew - bpbNew)
	alignb 2
.padding:
	alignb 16
endallocation:

%if (endallocation - $$) > 65520
 %error Too large
%endif
