
%if 0

lDOS iniload packed payload
 by E. C. Masloch, 2018-2020

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.


Includes one of several depackers, some of which are under
separate usage conditions. Refer to the individual depacker
source files for the applicable usage conditions.

%endif

%include "lmacros3.mac"

	struc LOADSTACKVARS, -10h
lsvFirstCluster:	resd 1
lsvFATSector:		resd 1
lsvFATSeg:		resw 1
lsvLoadSeg:		resw 1
lsvDataStart:		resd 1
	endstruc

	struc LOADDATA, LOADSTACKVARS - 10h
ldMemoryTop:	resw 1
ldLoadTop:	resw 1
ldSectorSeg:	resw 1
ldFATType:	resb 1
ldHasLBA:	resb 1
ldClusterSize:	resw 1
ldParaPerSector:resw 1
ldLoadingSeg:	resw 1
ldLoadUntilSeg:	resw 1
	endstruc


%ifndef _MAP
%elifempty _MAP
%else	; defined non-empty, str or non-str
	[map all _MAP]
%endif

	defaulting

	[list -]
%if __NASM_VERSION_ID__ >= 2000000h + 17 * 10000h
	numdef HAVE_NASM_NOTE, 1
 %note Disable usesection detection
%else
	numdef HAVE_NASM_NOTE, 0
%endif
%imacro hiddenusesection 1.nolist
 usesection %1
%endmacro

%unimacro usesection 1-2.nolist 0
	%imacro usesection 1-2.nolist 0
%ifndef _SECTION_ADDED_%1
 %error Section %1 not yet added
%endif
%if %2
%define _CURRENT_SECTION
%define _CURRENT_SECTION_TYPE
	[section %1]
%else
%xdefine _CURRENT_SECTION %1
%xdefine _CURRENT_SECTION_TYPE SECTION_TYPE_%1
	section %1
%endif
%if _HAVE_NASM_NOTE
 %note usesection %1
%endif
	%endmacro

%imacro noteincbin 2.nolist
%strcat %%string _PAYLOAD_PREFIX_LST, %2
%if _HAVE_NASM_NOTE
 %note include listing file %%string
%endif
	incbin %1
%endmacro
	[list +]

	numdef SCAN, 0

	numdef USESCAN, 0
	strdef SCANBINARY, ""

	numdef DEBUG0		; use errordata to generate an error code
	numdef DEBUG1		; dump_stack_frame after an error occurred
	numdef DEBUG2		; dump_stack_frame before blz_depack_safe call
	numdef DEBUG3		; dump_stack_frame at start of blz_depack_safe

	numdef OPTIMISE_INPUT_SMALL,	0
	numdef OPTIMISE_OUYPUT_SMALL,	0
	numdef ALLOW_OVERLAPPING,	1	; allow overlapping src and dst
	numdef TEST_PROGRAM,		0
	numdef TEST_PROGRAM_DECOMPRESSED_SIZE,		0,0
%if _TEST_PROGRAM && ! _TEST_PROGRAM_DECOMPRESSED_SIZE
 %error Test program has to learn of decompressed size.
%endif
	numdef TEST_PROGRESS,	0

	numdef INCLUDE_UNCOMPRESSED
	numdef INCLUDE_UNCOMPRESSED_IN_IMAGE, 1
	numdef WRITE_WRONG_FILE
	numdef RELOAD_XMS, 0
	numdef RELOAD_FILE, 0

	numdef EXEC_OFFSET,	0
	numdef EXEC_SEGMENT,	0
	numdef IMAGE_EXE,	0
%if ! _IMAGE_EXE && _TEST_PROGRAM
 %error Test program can only be used as EXE.
%endif
	numdef IMAGE_EXE_CS,	-16	; relative-segment for CS
	numdef IMAGE_EXE_IP,	256 +64	; value for IP
		; The next two are only used if _IMAGE_EXE_AUTO_STACK is 0.
	numdef IMAGE_EXE_SS,	-16	; relative-segment for SS
	numdef IMAGE_EXE_SP,	0FFFEh	; value for SP (0 underflows)
	numdef IMAGE_EXE_AUTO_STACK,	0, 2048	; use stack behind image
		; _IMAGE_EXE_AUTO_STACK here differs from iniload's def of
		;  the same name. This one is only used as a flag; if non-zero,
		;  keep the stack given to us by iniload; if zero, set up the
		;  stack specified by _IMAGE_EXE_SS and _IMAGE_EXE_SP.
	numdef IMAGE_EXE_GET_COM_STACK, 0
					; set up stack for flat .COM style entry
	numdef DEVICE,			0
	gendef DEVICE_NAME,		""
	numdef DEVICE_ATTRIBUTE,	8000h
	numdef DEVICE_ZERO_ENTRYPOINT,	0
	numdef BOOTLDR,		1	; support boot loaded entrypoint

	numdef BRIEFLZ,		0
	numdef LZ4,		0
	numdef SNAPPY,		0
	numdef EXODECR,		0
	numdef X,		0
	numdef HEATSHRINK,	0
	numdef LZD,		0
	numdef LZO,		0
	numdef LZSA2,		0
	numdef APL,		0
	numdef BZP,		0
	numdef ZEROCOMP,	0
	numdef MVCOMP,		0
	numdef LZEXEDAT,	0
	numdef ZX0,		0
%if (!!_BRIEFLZ + !!_LZ4 + !!_SNAPPY + !!_EXODECR + !!_X + !!_HEATSHRINK \
	+ !!_LZD + !!_LZO + !!_LZSA2 + !!_APL + !!_BZP + !!_ZEROCOMP \
	+ !!_MVCOMP + !!_LZEXEDAT + !!_ZX0) != 1
 %fatal Exactly one compression method must be selected.
%endif
%assign ADDITIONAL_MEMORY 0
%if _BRIEFLZ
	strdef PAYLOAD_FILE,	"lDOSLOAD.BLZ"
%elif _LZ4
	strdef PAYLOAD_FILE,	"lDOSLOAD.LZ4"
%elif _SNAPPY
	strdef PAYLOAD_FILE,	"lDOSLOAD.SZ"
%elif _EXODECR
	strdef PAYLOAD_FILE,	"lDOSLOAD.EXO"
%elif _X
	strdef PAYLOAD_FILE,	"lDOSLOAD.X"
%elif _HEATSHRINK
	strdef PAYLOAD_FILE,	"lDOSLOAD.HS"
%elif _LZD
	strdef PAYLOAD_FILE,	"lDOSLOAD.LZ"
%elif _LZO
	strdef PAYLOAD_FILE,	"lDOSLOAD.LZO"
%elif _LZSA2
	strdef PAYLOAD_FILE,	"lDOSLOAD.SA2"
%elif _APL
	strdef PAYLOAD_FILE,	"lDOSLOAD.APL"
%elif _BZP
	strdef PAYLOAD_FILE,	"lDOSLOAD.BZP"
%elif _ZEROCOMP
	strdef PAYLOAD_FILE,	"lDOSLOAD.ZER"
%elif _MVCOMP
	strdef PAYLOAD_FILE,	"lDOSLOAD.MV"
%elif _LZEXEDAT
	strdef PAYLOAD_FILE,	"lDOSLOAD.LZE"
%elif _ZX0
	strdef PAYLOAD_FILE,	"lDOSLOAD.ZX0"
%endif
	numdef PAYLOAD_KERNEL_MAX_PARAS,	0, 0
%if _PAYLOAD_KERNEL_MAX_PARAS && ! (_IMAGE_EXE || _DEVICE)
 %error Kernel mode max paras requires building dual-mode or triple-mode executable
%endif
	numdef COUNTER,		0, 32
%if (_COUNTER - 1) & _COUNTER
 %error COUNTER must be a power of two
%endif
	numdef PROGRESS,	0, 1
	numdef PROGRESSAMOUNT,	0, 0
	numdef PROGRESSMULTI,	1
	numdef PROGRESSVAR,	1
	numdef PROGRESSVARNAME, ""
	numdef PROGRESSDEFAULT,	0
	numdef PROGRESSDEFAULTAPP,	_PROGRESSDEFAULT
	numdef PROGRESSDEFAULTDEVICE,	_PROGRESSDEFAULT
	numdef PROGRESSDEFAULTBOOT,1
	numdef PASSLCFG, 0
	numdef LCFG, (_PROGRESS && _PROGRESSMULTI) || _PASSLCFG


%define MODULE inicomp
	strdef INILOAD_CFG, ""
%ifnidn _INILOAD_CFG, ""
 %include _INILOAD_CFG
%endif
	strdef LCFG_CFG, ""

%if _DEVICE
 %ifidn _DEVICE_NAME, ""
  %error Device name must be set
 %endif
%endif

	struc XMSM
.size_:		resd 1
.srchdl:	resw 1
.srcadr:	resd 1
.dsthdl:	resw 1
.dstadr:	resd 1
	endstruc


	cpu 8086
[list -]
%ifn _SCAN
[list +]

	addsection INIT0, start=0 vstart=0
init0_start:
%if _DEVICE
		; The device header is of a fixed format.
		;  For our purposes, the 4-byte code for
		;  each the strategy entry and the
		;  interrupt entry is part of this format.
		; (DOS may read the attributes or entrypoint
		;  offsets before calling either, so in the inicomp
		;  stage we need to recreate in the entrypoints part
		;  exactly what the application has here.)
		; _PASSLCFG: The lCFG block is passed in the dword
		;  behind the interrupt entry.
device_header:
.next:
 %if _DEVICE_ZERO_ENTRYPOINT
	fill 2, -1, jmp strict short j_zero_entrypoint
	dw -1
 %else
	dd -1				; link to next device
 %endif
.attributes:
	dw _DEVICE_ATTRIBUTE		; attributes
.strategy:
	dw .strategy_entry		; -> strategy entry
.interrupt:
	dw .interrupt_entry		; -> interrupt entry
.name:
	fill 8, 32, db _DEVICE_NAME	; character device name,
					;  or block device number of units
					;  + optional name
.strategy_entry:
	fill 4, 90h, jmp device_entrypoint
.interrupt_entry:
	fill 4, 90h, retf
.pass_lcfg:
%endif


%if _IMAGE_EXE || _DEVICE
	nop
	align 32, nop
init0_kernel_entry:
		; cs:ip = load seg : 32 here
%if ($ - $$) != 32
 %error Wrong kernel mode entrypoint
%endif
%if _TEST_PROGRAM
@@:
	int3
	sti
	hlt
	jmp @B
%endif
%if _BOOTLDR
%if ! _IMAGE_EXE
j_zero_entrypoint:
%endif
	xor bx, bx		; 0 = kernel mode
	push ax
	mov ax, cs
	add ax, (init0_end - init0_start) >> 4
	mov dx, word [ bp + ldLoadTop ]	; => after end of available space
	mov si, 60h		; => destination
	jmp init0_common
%endif

 %if _IMAGE_EXE
	align 64, nop
j_zero_entrypoint:
init0_exe_entry:
		; NOTE:	This part is called with ip = 256 + 64, cs = PSP.
%if ($ - $$) != 64
 %error Wrong EXE mode entrypoint
%endif
%if _IMAGE_EXE_GET_COM_STACK
	mov bx, ds		; => PSP
	dec bx			; => MCB
	mov ds, bx
	add bx, word [3]	; add size of memory block
	sub bx, -1 + paras(512)	; add one, then subtract enough paragraphs
	cli
	mov ss, bx
	mov sp, 512		; -> new stack
	sti
%endif
	mov bx, 1		; EXE mode
	push ax
  %if _TEST_PROGRAM
%if (_INCLUDE_UNCOMPRESSED && ! _INCLUDE_UNCOMPRESSED_IN_IMAGE) || _RELOAD_FILE
	push ds
	mov ax, word [2Ch]	; => environment
	test ax, ax
	jnz @F
.errorfile:
	jmp init0_error_file
@@:
	mov ds, ax
	mov cx, 8000h
	xor si, si		; -> environment
@@:
	lodsb
	test al, al
	loopnz @B		; si -> past one NUL
	jcxz .errorfile
	cmp byte [si], 0	; -> another NUL ?
	loopne @B		; no, skip next variable -->
	jcxz .errorfile
	inc si			; skip double NUL
	lodsw			; load amount strings after environment
	cmp ax, 1		; 1 ?
	jne .errorfile		; no -->
	mov dx, si		; ds:dx -> executable pathname
	mov ax, 3D00h + 0_010_0_000b	; deny write, read only
	int 21h			; open
	jc .errorfile
	pop ds			; restore => PSP
	push ax			; push into ?handle
%endif

	mov si, 81h
	xor dx, dx
	xor ax, ax
cmdline:
.:
	lodsb
	cmp al, 9
	je .
	cmp al, 32
	je .
	cmp al, 13
	je .end
	cmp al, '0'
	jb .notdigit
	cmp al, '9'
	ja .notdigit
.digit:
	sub al, '0'
	mov cx, dx		; times 1
	add dx, dx
	jc .invalid
	add dx, dx		; times 4
	jc .invalid
	add dx, cx		; times 5
	jc .invalid
	add dx, dx		; times 10
	jc .invalid
	add dx, ax		; add in low digit
	jc .invalid
	jmp .

.notdigit:
	cmp al, 'A'
	je .a
	cmp al, 'a'
	je .a
	cmp al, 'B'
	je .b
	cmp al, 'b'
	je .b
	cmp al, 'C'
	je .c
	cmp al, 'c'
	je .c
.invalid:
	mov dx, -1		; invalid
	jmp .end

.a:
	and bh, ~ 80h		; A mode. determine min alloc size
	jmp .

.b:
	or bh, 80h		; B mode. repeat depack, counter in command line
	jmp .

.c:
	or bh, 40h		; C mode. how often would the counter be called
	jmp .

.end:
				; bx for ?whichtest
	push dx			; for ?repetitions
  %endif
	mov dx, ss		; => after end of available space
	mov ax, cs
	add ax, (256 + (init0_end - init0_start)) >> 4	; => source
	mov si, cs
	add si, 256 >> 4	; => destination
 %endif

init0_common:
		; REM:	This part must be position-independent, as it is
		;	 called either with ip = init0_common (kernel mode
		;	 or device mode)
		;	 or ip = init0_common + 256 (application mode).
		; INP:	si => depack destination
		;	ax => source of payload + INIT1
		;	dx => behind available memory
		; OUT:	cs:ip -> init1_start:
		;	ax => INIT1
		;	dx => payload source
		;	si => depack destination
		;	bx = mode
	cld
%if _TEST_PROGRAM
 %ifn _RELOAD_XMS || _RELOAD_FILE
	sub dx, ( (payload_end - payload) ) >> 4
	jc .error
 %endif
	mov cx, ( \
		+ (init0b_end - init0b_start) \
		+ (payload_end - payload) \
		+ (init1_end - init1_start) \
		+ (init2_end - init2_start) \
		) >> 4
	sub dx, cx
	jc .error
	cmp dx, ax
	jb .error
%else
	mov cx, ( \
		+ (init0b_end - init0b_start) \
		+ (payload_end - payload) \
		+ (init1_end - init1_start) \
		) >> 4
				; cx = amount paragraphs in INIT0B + payload + INIT1
	sub dx, cx		; => destination for INIT0B + payload + INIT1
				;  (highest possible spot in available memory)
%endif
	push si			; preserve destination
	call init0_movp		; move up payload + INIT1
	pop si
%else
	cld
	mov ax, cs
	add ax, (init0_end - init0_start) >> 4
	mov cx, ( \
		+ (init0b_end - init0b_start) \
		+ (payload_end - payload) \
		+ (init1_end - init1_start) \
		) >> 4
	mov dx, word [ bp + ldLoadTop ]
	sub dx, cx
	call init0_movp
%endif

%if _LCFG && ! _TEST_PROGRAM
	push cs
	call @F			; position-independent far pointer
@@:
	pop ax
	add ax, lcfg - @B	; -> lCFG block
	push ax
%endif

	mov ax, dx		; => INIT0B
				;  (same as => payload if INIT0B is empty)
%if (_LCFG || _PROGRESS) && ! _TEST_PROGRAM
	add dx, ( \
		+ (init0b_end - init0b_start) \
		) >> 4		; => payload
%else
 %if _TEST_PROGRAM
	add ax, ( \
		+ (init0b_end - init0b_start) \
		+ (payload_end - payload) \
		+ (init1_end - init1_start) \
		) >> 4		; => INIT2
 %else
	add ax, ( \
		+ (init0b_end - init0b_start) \
		+ (payload_end - payload) \
		) >> 4		; => INIT1
 %endif
%endif
	xor cx, cx
	push ax
	push cx
	retf			; jump to relocated
				;  INIT0B:init0b_start
				;  or INIT1:init1_start
				;  or INIT2:init2_start


%if _TEST_PROGRAM
.error:
	mov di, bx		; whichtest

	push cs
	pop ds
	mov dx, init0_msg.error_stderr + 256
	mov cx, init0_msg.error_stderr.length
	mov bx, 2
	mov ah, 40h
	int 21h

	test di, 4000h		; whichtest
	jz @F
	mov dx, init0_msg.error_c_stdout + 256
	mov cx, init0_msg.error_c_stdout.length
	jmp @FF
@@:
	test di, di		; whichtest
	js @FF
	mov dx, init0_msg.error_stdout + 256
	mov cx, init0_msg.error_stdout.length
@@:
	mov bx, 1
	mov ah, 40h
	int 21h
@@:
	mov ax, 4CFFh
	int 21h

%if (_INCLUDE_UNCOMPRESSED && ! _INCLUDE_UNCOMPRESSED_IN_IMAGE) || _RELOAD_FILE
init0_error_file:
	mov dx, init0_msg.error_stderr_file + 256
	mov cx, init0_msg.error_stderr_file.length
	push cs
	pop ds
	mov bx, 2
	mov ah, 40h
	int 21h

	mov dx, init0_msg.error_stdout + 256
	mov cx, init0_msg.error_stdout.length
	mov bx, 1
	mov ah, 40h
	int 21h
	mov ax, 4CFFh
	int 21h
%endif

%endif


%if _LCFG
	%imacro lcfgoption 3+.nolist
	_fill %1, 0, lcfg
%%start:
	%2
	%3
%%end:
%assign %%index %%start - lcfg
%rep %%end - %%start
%assign LCFGINUSE LCFGINUSE | (1 << %%index)
 %assign %%index %%index + 1
%endrep
	%endmacro
%assign LCFGINUSE 0

	align 16
lcfg:
.:		jmp strict short .end
lcfgoption 2,,	db "lCFG"
lcfgoption 6,,	db "00"
lcfgoption 8,,	dq .inuse
 %if _PROGRESS && _PROGRESSMULTI
  %if _IMAGE_EXE
lcfgoption 16, .progress_app:, db _PROGRESSDEFAULTAPP
  %endif
  %if _DEVICE
lcfgoption 17, .progress_dev:, db _PROGRESSDEFAULTDEVICE
  %endif
  %if _BOOTLDR
lcfgoption 18, .progress_boot:, db _PROGRESSDEFAULTBOOT
  %endif
 %endif

%ifnidn _LCFG_CFG, ""
 %include _LCFG_CFG
%endif

lcfgoption 32,,
.end:
.size: equ .end - .
.inuse equ LCFGINUSE
%endif


%if _DEVICE
device_entrypoint:
%if _TEST_PROGRAM
@@:
	int3
	sti
	hlt
	jmp @B
%endif
	cmp byte [es:bx + 2], 0		; command code 0 (init) ?
	je @F

	mov word [es:bx + 3], 8103h	; error, done, code: unknown command
	retf

@@:
	or word [cs:device_header.next], -1
	push cs
	push word [cs:device_header.strategy]
					; -> far return to payload's strategy
	push bp
	push ds
	push si
	push di
	push dx
	push cx
	push ax
	push bx
	push es

	mov dx, word [es:bx + 14]
	mov cl, 4
	shr dx, cl		; = how many full paragraphs (rounded down)
	add dx, word [es:bx + 14 + 2]
				; ax => behind end

	mov di, cs
image_size: equ  ( \
		+ (init0_end - init0_start) \
		+ (init0b_end - init0b_start) \
		+ (payload_end - payload) \
		+ (init1_end - init1_start) \
		)
	add di, image_size >> 4		; di => end of image

	cmp dx, di			; enough memory to hold all of us ?
	jb @F				; no -->
				; yes
.have_some_memory:
				; dx => after end of memory
	mov bx, 2		; device mode
	push ax
	mov ax, cs
	add ax, (init0_end - init0_start) >> 4
	mov si, cs		; => destination
	jmp init0_common


@@:
	push cs
	pop ds
	mov dx, .msg_no_memory
	mov ah, 09h
	int 21h

	mov ax, 3000h
	int 21h
	cmp al, 5
	jae @F
	mov dx, .msg_dos_below_5
	mov ah, 09h
	int 21h
@@:

	mov dx, .msg_linebreak
	mov ah, 09h
	int 21h

		; tear down the stack frame and modify the request header
	pop es
	pop bx
	mov word [es:bx + 3], 8103h	; set error, done, invalid command
	mov byte [es:bx + 13], 0	; set number of units = 0
	mov word [es:bx + 14 + 2], cs
	and word [es:bx + 14], 0	; -> after end of memory to allocate
	pop ax
	pop cx
	pop dx
	pop di
	pop si
	pop ds
	pop bp
	add sp, 4		; discard far return to payload's strategy
	retf			; return to DOS


.msg_no_memory:		ascic "Load error: Not enough memory."
.msg_dos_below_5:	ascic " Note: DOS must be at least version 5."
.msg_linebreak:		ascic 13,10
%endif


		; Move paragraphs
		;
		; INP:	ax => source
		;	dx => destination
		;	cx = number of paragraphs
		; CHG:	cx, ds, si, es, di
		; OUT:	ax and dx unchanged
		; Note:	Doesn't work correctly on HMA; doesn't always wrap to LMA either.
		;	Do not provide a wrapped/HMA source or destination!
init0_movp:
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
	retn


	addsection INIT0B, align=16 vstart=0 follows=INIT0
		; INP:	ax:cx = cs:ip = cs:0
		;	ax => INIT0B
		;	dx => payload source
		;	ss:sp -> (dword pointer to lCFG block)
		;	if app/device mode supported:
		;	 si => depack destination
		;	 bx = mode
init0b_start:
%if _LCFG || _PROGRESS

	add ax, ( \
		+ (init0b_end - init0b_start) \
		+ (payload_end - payload) \
		) >> 4		; => INIT1

%if _LCFG && _PASSLCFG
 %if (_IMAGE_EXE || _DEVICE)
	mov cx, si		; preserve si
 %endif
	pop si
	pop ds			; -> lCFG block
	mov es, ax
	mov di, transfer_lcfg_block
				; -> destination
 %if (_IMAGE_EXE || _DEVICE)
	push cx
 %endif
	push di
	mov cx, words(lcfg.size)
	rep movsw		; cx = 0
	pop di			; es:di -> relocated lCFG block, same difference
 %if (_IMAGE_EXE || _DEVICE)
	pop si			; preserve si
 %endif
%elif _LCFG
	pop di
	pop es			; es:di -> (original) lCFG block
%endif

	push ax
	push cx			; -> far return address to init1_start

%if _PROGRESS && _PROGRESSMULTI
 %if (_IMAGE_EXE || _DEVICE)
	push si
	push bx
 %endif
 %if _BOOTLDR
  %if _LCFG
	xor ax, ax
	mov al, byte [es:di + lcfg.progress_boot - lcfg]
	xchg di, ax		; di = boot default progress
				; es:ax -> lCFG block
  %else			; _LCFG
	mov di, _PROGRESSDEFAULTBOOT
  %endif		; _LCFG
 %endif			; _BOOTLDR
 %if (_IMAGE_EXE || _DEVICE)
  %if _BOOTLDR
	test bx, bx
	jz .default
  %endif		; _BOOTLDR
  %if _LCFG
	push es
   %if _BOOTLDR
	push ax			; -> lCFG block
   %else		; _BOOTLDR
	push di
   %endif		; _BOOTLDR
  %endif		; _LCFG
  %if _PROGRESSVAR
	mov ah, 51h
	int 21h
@@:
	mov ds, bx
	mov ax, word [2Ch]
	test ax, ax
	jnz .gotenv
	mov ax, word [16h]
	inc ax
	jz .default_nonboot
	dec ax
	jz .default_nonboot
	cmp bx, ax
	je .default_nonboot
	xchg bx, ax
	jmp @B

.gotenv:
	push cs
	pop ds				; => cs
	mov es, ax			; => environment
 %ifnidni _PROGRESSVARNAME, ""
	mov bx, progressvarname1
	call .findenv
	jnc .foundenv			; match -->
	mov bx, progressvarname2
 %endif
	call .findenv
	jnc .foundenv			; match -->
	jmp .default_nonboot

.findenv:
	xor di, di
@@:
 %ifnidni _PROGRESSVARNAME, ""
	mov si, bx			; -> variable name
 %else
	mov si, progressvarname2	; -> variable name
 %endif
	xor ax, ax
	lodsb				; get length
	xchg cx, ax			; cx = length
	push di
	repe cmpsb			; match ?
	je .findret_pop			; (NC) yes -->
	pop di
	mov cx, 8000h			; maximum env size
	sub cx, di			; any left ?
	jbe .findret_CY			; no -->
	mov al, 0
	repne scasb			; find next NUL
	jne .findret_CY
	cmp byte [es:di], al		; double NUL ?
	jne @B				; no, loop -->
.findret_CY:
	stc				; not found
	retn

.findret_pop:
	pop cx
	retn

.foundenv:
%if _LCFG
	pop si
	pop si				; discard far pointer to lCFG
%endif
	mov si, di			; es:si -> var content
	xor di, di			; = 0
	xor ax, ax			; ah = 0
@@:
	es lodsb			; next candidate digit
	sub al, '0'			; digit ?
	jb @F				; no -->
	cmp al, 9
	ja @F				; no -->
	add di, di			; times 2
	mov bx, di
	add di, di			; times 4
	add di, di			; times 8
	add di, bx			; times 8 + times 2 = times 10
	add di, ax			; add in next digit
	jmp @B				; and loop

@@:
	and di, 31			; mask to low 5 bits
	jmp @F
  %endif	; _PROGRESSVAR

.default_nonboot:
%if _LCFG
	pop di
	pop es			; -> lCFG block
	pop bx			; = 1 if app, = 2 if device
	push bx
	mov ax, word [es:di + lcfg.progress_app - lcfg]
 %if _DEVICE
  %if lcfg.progress_app + 1 != lcfg.progress_dev
   %error Unexpected layout
  %endif
				; al = app, ah = device
	dec bx
	jz .default_app
	xchg al, ah		; al = device
.default_app:
 %endif			; _DEVICE
	mov ah, 0		; ax = default
	xchg di, ax		; di = default
%else			; _LCFG
	mov di, _PROGRESSDEFAULT
%endif			; _LCFG
@@:
	test di, 16
	jz @F
	and di, ~16
	jmp .outputdevice	; if 16 set skip device check
@@:
	push dx
	mov ax, 4400h		; IOCTL get device information
	mov bx, 1		; StdOut
	mov dl, 83h		; default if 21.4400 fails
	int 21h
	test dl, 80h
	pop dx
	jnz .outputdevice
	xor di, di		; stdout is a file: force no progress marker
.outputdevice:
 %endif			; (_IMAGE_EXE || _DEVICE)

.default:
 %if (_IMAGE_EXE || _DEVICE)
	pop bx
	pop si
 %endif
	cmp di, step_progress_table.amount
					; valid ?
	jb @F				; yes -->
	xor di, di			; disable
@@:
	shl di, 1			; = word index
	pop cx				; = 0
	pop ds				; ds => INIT1

	mov ax, word [cs:step_progress_table + di]
					; ax = rel16 for step progress handler
	push ds
	push cx				; -> init1_start
	mov word [step_progress.handler], ax
					; patch it

	cmp di, 2 * 2			; none or dots ?
	jae @F				; no, skip -->
	mov byte [..@empty_step_progress], __TEST_IMM16
					; for none and dots do not call here
@@:
%endif			;  _PROGRESS && _PROGRESSMULTI
	retf
%endif

%if _PROGRESS && _PROGRESSMULTI
		align 2, db 0
step_progress_table:
.:
		dw step_progress.0_step - step_progress.base
		dw step_progress.1_step - step_progress.base
		dw step_progress.2_step - step_progress.base
		dw step_progress.3_step - step_progress.base
		dw step_progress.4_step - step_progress.base
.amount equ ($ - .) / 2

 %if _PROGRESSVAR && (_IMAGE_EXE || _DEVICE)
  %ifnidni _PROGRESSVARNAME, ""
progressvarname1:	counted _PROGRESSVARNAME, '='
  %endif
progressvarname2:	counted "LDOSPROGRESS="
 %endif
%endif

	align 16
init0b_end:


	addsection PAYLOAD, align=16 follows=INIT0B
payload:
	incbin _PAYLOAD_FILE
.end:
	align 16, db 38
payload_end:

%if _OPTIMISE_INPUT_SMALL
 %ifn (payload_end - payload) <= 65_520
  %error Input declared small is not small
 %endif
%else
 %if (payload_end - payload) <= 65_520
  %warning Input could be declared small
 %endif
%endif


	addsection INIT1, align=16 follows=PAYLOAD vstart=0
init1_start:
		; INP:	ax = cs = INIT1
		;	dx = cs - (payload_end - payload) >> 4 => source data
		;	if kernel mode:
		;	 ss:bp -> LOADDATA and LOADSTACKVARS
		;	 ss:sp -> valid stack above [bp + ldLoadTop]
		;	 60h => destination
		;	any mode:
		;	 ss:sp -> word value for ax
		;	 bx = 2 if device mode, 1 if EXE mode, 0 if kernel mode
		;	 si => destination (60h for kernel mode,
		;		after PSP for EXE mode,
		;		at device header for device mode)
		;		(not set if only kernel mode supported)
		;	 if EXE mode:
		;	  ss:sp -> valid stack above INIT1
		;	  bp = unset
		;	 if device mode:
		;	  ss:sp -> device entrypoint stack
		;	  holds: es, bx, ax, cx, dx, di, si, ds, bp,
		;		  far address of payload strategy entrypoint,
		;		  far return address to DOS
		;	  bp = unset
		; STT:	UP
		; CHG:	ax, bx, cx, dx, es, ds, si, di
%if _IMAGE_EXE || _DEVICE
	lframe
	lenter
	lvar word,	exemode		; must be bp - 2!
	 push bx
 %if ?exemode != -2
  %error exemode variable must be directly below bp
 %endif
	push si
 %if _PROGRESS
	clc			; NC
 %endif
%else
	xor bx, bx		; always tell them it is kernel mode (NC)
%endif

%if _PROGRESS
	; clc
..@empty_step_progress:		; SMC, byte patched to __TEST_IMM16 if none or dots
 %if _TEST_PROGRAM
	times 3 nop
 %else
	call step_progress.CF	; display empty / 0.0%
 %endif
@@:
%endif

%if _IMAGE_EXE || _DEVICE
	mov es, si		; es => destination
%else
	mov ax, 60h
	mov es, ax		; es => destination
%endif
	xor di, di		; -> destination

	mov ds, dx
	xor si, si		; -> source

	mov cx, (payload.end - payload) & 0FFFFh
%if (payload.end - payload) >> 16
	mov dx, (payload.end - payload) >> 16	; = length of source
%else
	xor dx, dx
%endif
%if _PAYLOAD_KERNEL_MAX_PARAS
	mov ax, _PAYLOAD_KERNEL_MAX_PARAS
	test bx, bx
	jz @F
%endif
	mov ax, -1
@@:

		; INP:	ds:si -> source
		;	dx:cx = length of source
		;	es:di -> destination (below source)
		;	bx = EXE mode flag
		;	 (1 if EXE mode, 0 if kernel mode)
		;	 (always 0 if this is a build without EXE mode)
		;	if _PAYLOAD_KERNEL_MAX_PARAS:
		;	 ax = maximum amount in paragraphs of destination needed
		;	 (-1 if full source should be decompressed)
		;	else:
		;	 ax = -1
		; Note:	The destination reaches up to below the source.
	call depack
%ifn _TEST_PROGRAM
	jc strict short error	; -2 (replaced by retf \ nop)
%endif
%if _IMAGE_EXE || _DEVICE
	pop si			; si
 %if _TEST_PROGRAM
	pop ax			; (discard ?exemode, leave bx as returned)
 %else
	pop bx			; ?exemode
 %endif
	pop bp			; bp
	pop ax			; ax
	lleave ctx
%endif
%if _TEST_PROGRAM
	retf			; +1 (replace jc error)
	nop			; +1
%endif

%if _DEVICE
	test bl, 2
	jz .jmp_exe_or_kernel_mode

.jmp_device_mode:
	mov ds, si
	or word [device_header.next], -1
%if _LCFG && _PASSLCFG
	mov word [device_header.pass_lcfg], transfer_lcfg_block
	mov word [device_header.pass_lcfg + 2], cs
%endif
	pop es
	pop bx
	pop ax
	pop cx
	pop dx
	pop di
	pop si
	pop ds
	pop bp
	retf			; transfer to payload strategy entrypoint
				; still on stack: far return address to DOS

.jmp_exe_or_kernel_mode:
%endif

%if _IMAGE_EXE
	test bl, 1
	jz .jmp_kernel_mode

.jmp_exe_mode:
%if ! _IMAGE_EXE_AUTO_STACK
	mov cx, cs
	lea dx, [si + _IMAGE_EXE_SS]
	push dx			; stack = relocated ss value
	add dx, (_IMAGE_EXE_SP + 2 + 15) >> 4
	cmp cx, dx		; INIT1 code is above intended stack ?
	jae @F			; yes -->

	lframe
	lenter
	lvar	word, exemode
	 push bx
 %if ?exemode != -2
  %error exemode variable must be directly below bp
 %endif
	mov bx, -1		; unimplemented, return error
	jmp error
	lleave ctx
@@:
	cli
	pop ss			; = relocated ss value
	mov sp, (_IMAGE_EXE_SP + 2) & 0FFFFh	; change stack
	sti
%endif

	xor cx, cx
	push cx			; put zero on top of stack

%if _IMAGE_EXE_IP < 256
	mov cl, _IMAGE_EXE_IP
%elif (_IMAGE_EXE_IP & 255) == 0
	mov ch, _IMAGE_EXE_IP >> 8
%else
	mov cx, _IMAGE_EXE_IP
%endif

%if _IMAGE_EXE_CS == -16
	add si, -16
	mov ds, si
	mov es, si
%else
	lea dx, [si - 10h]	; => PSP
	mov ds, dx
	mov es, dx		; ds = es => PSP
 %if _IMAGE_EXE_CS
	add si, _IMAGE_EXE_CS	; = relocated cs value
 %endif
%endif
	push si
	push cx
%if _LCFG && _PASSLCFG
	mov di, transfer_lcfg_block
	mov cx, cs
%endif
	retf			; jump to EXE mode of image

%endif
.jmp_kernel_mode:
%if _LCFG && _PASSLCFG
	mov di, transfer_lcfg_block
	mov cx, cs
%endif
	jmp 60h + _EXEC_SEGMENT:_EXEC_OFFSET


%if _TEST_PROGRAM
disp_al_counter:
	inc word [cs:init1_c_mode_counter]	; 5 bytes
	retn					; 1 byte

init1_c_mode_counter:		dw 0		; 2 bytes, total 8
%else
 %if _PROGRESS
disp_al_counter equ step_progress
 %else
disp_al_counter equ disp_al
 %endif
%endif


error:
 %ifn _TEST_PROGRAM		; 2 bytes
	push cs
	pop ds
 %endif
%if _DEBUG0
	mov si, msg.error_begin
	call disp_error
	xchg ax, bx			; ax = error code
	call disp_ax_hex
 %ifn _TEST_PROGRAM		; 3 bytes
	mov si, msg.error_end
 %endif
%else
 %ifn _TEST_PROGRAM		; 3 bytes
	mov si, msg.error
 %endif
%endif
 %ifn _TEST_PROGRAM		; 3 bytes, total 2 + 3 + 3 = 8
	call disp_error
 %endif
%if _DEVICE
	test byte [bp - 2], 2
	jz .exit_app_or_kernel

	pop si				; => device segment
	pop bx				; mode word
	pop bp
	pop ax
	mov es, si
	xor di, di			; -> device header
	 push cs
	 pop ds
	mov si, device_header_copy	; -> to reset header
	mov cx, words(device_header_copy.length)
	rep movsw		; overwrite device header with default
				;  (reset to a valid state after unsuccessful
				;  decompression, which may have partially
				;  written the header already)
	 push es
	 pop ds				; -> device segment
	pop es
	pop bx
	mov word [es:bx + 3], 8103h	; set error, done, invalid command
	mov byte [es:bx + 13], 0	; set number of units = 0
	mov word [es:bx + 14 + 2], ds
	and word [es:bx + 14], 0	; -> after end of memory to allocate
	pop ax
	pop cx
	pop dx
	pop di
	pop si
	pop ds
	pop bp
	add sp, 4		; discard far return to payload's strategy
	retf			; return to DOS


.exit_app_or_kernel:
%endif

%if _IMAGE_EXE
%if _BOOTLDR
	test byte [bp - 2], 1
	jz .exit_kernel_mode
%endif

	mov ax, 4C7Fh
	int 21h

.exit_kernel_mode:
%endif
%if _BOOTLDR
	xor ax, ax
	int 16h
	int 19h
%endif


%if _PROGRESS
step_progress:
	stc
.CF:
	push bx
	push cx
	push dx
	push ds
	push si
	push di
	push ax

	push cs
	pop ds

	adc word [.counter], 0
	mov ax, word [.counter]

 %if _PROGRESSMULTI
  %if _IMAGE_EXE || _DEVICE
   %assign defaultprogresshandler _PROGRESSDEFAULT
  %else
   %assign defaultprogresshandler _PROGRESSDEFAULTBOOT
  %endif
	jmp strict near . %+ defaultprogresshandler %+ _step
.handler: equ $ - 2		; SMC, patched to dispatch to handler
.base:
 %endif

.2_step:
	mov dx, 1000
	mul dx			; dx:ax = counter times 1000
%if _PROGRESSAMOUNT
	mov cx, _PROGRESSAMOUNT
	div cx			; ax = 0..1000
%else
 %warning Progress amount is zero
	mov ax, 1
%endif

%if 0
	cmp word [.display], ax
	je .ret
	mov word [.display], ax
%endif
	mov si, .message_number_end - 1
	call .format_percentage

	mov si, .message
	call disp_error

.ret:
	pop ax
.ret_ax:
	pop di
	pop si
	pop ds
	pop dx
	pop cx
	pop bx
.retn:
	retn


.format_percentage:
	mov bx, 2		; skip dot

	mov cx, 10		; base
@@:
	xor dx, dx		; dx:ax = current number
	div cx			; dl = remainder, ax = next number
	add dl, '0'		; make decit
	mov byte [si], dl	; store
	sub si, bx		; -> next digit slot
	cmp bl, 2		; did we just store fractional ?
	mov bl, 1		; ! next iteration do not skip dot
	je @B			; yes, loop always -->
	test ax, ax		; nonzero left ?
	jnz @B			; yes, loop if so -->
	retn


 %if _PROGRESSMULTI
.0_step: equ .ret

.1_step:
	pop ax
	call disp_al
	jmp .ret_ax

.3_step:
	mov bx, 80 - 1 - 4
	mul bx			; dx:ax = counter times 75
%if _PROGRESSAMOUNT
	mov cx, _PROGRESSAMOUNT
	div cx			; ax = 0..75
%else
 %warning Progress amount is zero
	mov ax, 1
%endif

	cmp word [.display], ax
	je .ret
	mov word [.display], ax

	push ax
	xchg cx, ax
	mov al, 13
	call disp_al
	mov al, '['
	call disp_al
	mov al, 32
	call disp_al

	mov al, '#'
	jcxz @FF
@@:
	call disp_al
	loop @B
@@:

	mov al, 32
	pop cx
	sub bx, cx
	jbe @FF
	mov cx, bx
@@:
	call disp_al
	loop @B
@@:

.m4done:
	call disp_al
	mov al, ']'
	call disp_al
	jmp .ret


.4_step:
	push ax

	mov dx, 1000
	mul dx			; dx:ax = counter times 1000
%if _PROGRESSAMOUNT
	mov cx, _PROGRESSAMOUNT
	div cx			; ax = 0..1000
%else
 %warning Progress amount is zero
	mov ax, 1
%endif

	mov si, .message_4_number_end - 1
	call .format_percentage

	pop ax
	mov bx, 80 - 1 - 4
	mul bx			; dx:ax = counter times 75
%if _PROGRESSAMOUNT
	mov cx, _PROGRESSAMOUNT
	div cx			; ax = 0..75
%else
 %warning Progress amount is zero
	mov ax, 1
%endif

	push ax
	xchg cx, ax
	mov al, 13
	call disp_al
	mov al, '['
	call disp_al
	mov al, 32
	call disp_al

	xor di, di
	mov dx, (80 - 1 - 4 - .message_4_length) / 2
	cmp byte [.message_4_number], 32
	je @F
	inc di
@@:
	sub dx, di

	mov al, '#'
	jcxz @FF
@@:
	call disp_al
	dec dx
	loopnz @B
@@:

	test dx, dx
	jnz .notyetm4

	mov si, .message_4
	sub si, di
	call disp_error

	sub cx, di
	jbe @FF
	sub cx, .message_4_length
	jbe @FF
	mov dx, cx
	mov al, '#'
@@:
	call disp_al
	loop @B
@@:
	pop cx
	mov al, 32
	sub bx, (80 - 1 - 4 - .message_4_length) / 2 + .message_4_length
	sub bx, dx
	jbe @FF
	mov cx, bx
@@:
	call disp_al
	loop @B
@@:
	jmp .m4done

.notyetm4:
	mov al, 32
	pop cx
	sub bx, cx
	jbe @FF
	mov cx, bx
@@:
	call disp_al
	dec dx
	loopnz @B
@@:

	mov si, .message_4
	sub si, di
	call disp_error

	mov al, 32
	sub cx, di
	sub cx, .message_4_length
	; jbe @FF
@@:
	call disp_al
	loop @B
@@:
	jmp .m4done
%endif

	align 2, db 0
 %if _PROGRESSMULTI
.display:	dw -1
 %endif
.counter:	dw 0
.message:	db 13,"[ "
.message_number:db "  1.0"	; enough digit slots for 100.0%,
				;  blanks are pre-init until written
.message_number_end:
		db "% ]",0
 %if _PROGRESSMULTI
		db " "
.message_4:
.message_4_number:db "  1.0"	; enough digit slots for 100.0%,
				;  blanks are pre-init until written
.message_4_number_end:
		db "% ",0
.message_4_length: equ $ - 1 - .message_4
 %endif
%endif


%if _DEVICE
	align 16
device_header_copy:
.:
.next:
	dd -1				; already initialised
.attributes:
	dw _DEVICE_ATTRIBUTE
.strategy:
	dw .strategy_entry - .		; -> strategy entry
.interrupt:
	dw .interrupt_entry - .		; -> interrupt entry
.name:
	fill 8, 32, db _DEVICE_NAME

.strategy_entry:
	fill 4, 90h, jmp .set_error	; rel8 or rel16 jump, not minus .
.interrupt_entry:
	fill 4, 90h, retf

.set_error:
	mov word [es:bx + 3], 8103h	; set error, done, invalid command
	retf
.length: equ $ - .
%endif


disp_error.loop:
	call disp_al
disp_error:
	lodsb
	test al, al
	jnz .loop
	retn

%if _DEBUG0 || _DEBUG1 || _DEBUG2 || _DEBUG3
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
%endif


disp_al_for_progress:
%if _PROGRESS && _PROGRESSMULTI
	cmp word [cs:step_progress.handler], step_progress.0_step - step_progress.base
	je disp_al.retn
%endif
disp_al:
%if _TEST_PROGRAM
	retn
%else
	push ax
%endif
%if _BOOTLDR
	push bx
	push bp
	mov ah, 0Eh
	mov bx, 7
%endif
%if _IMAGE_EXE || _DEVICE
	push dx

%if _BOOTLDR
	test byte [bp - 2], 1 | 2
	jz .display_kernel_mode
%endif

	xchg dx, ax				; dl = input al
	mov ah, 02h
	int 21h
%if _BOOTLDR
	db __TEST_IMM16				; (skip int)
%endif

.display_kernel_mode:
%endif
%if _BOOTLDR
	int 10h
%endif
%if _IMAGE_EXE
	pop dx
%endif
%if _BOOTLDR
	pop bp
	pop bx
%endif
	pop ax
.retn:
disp_error.ret:
	retn


msg:
%if _DEBUG0
.error_begin:	db "Load error: Decompression failure, code ",0
.error_end:	db "h.",13,10,0
%else
.error:		db "Load error: Decompression failure.",13,10,0
%endif


%endif	; _SCAN
[list +]

%assign NEED_NORMALISE_POINTER_WITH_DISPLACEMENT 1
%assign NEED_NORMALISE_BOTH_POINTERS 1
%assign CHECK_POINTERS_VARIABLE_SRC 1
%assign CHECK_POINTERS_VARIABLE_DST 1
%assign SCAN_SUPPORTED 0

		; Specific depacker's file is included within label msg.
		; In the file, lframe is used and lleave ctx is not used.

%if _BRIEFLZ
	%include "brieflz.asm"
%endif


%if _LZ4
	%include "lz4.asm"
%endif


%if _SNAPPY
	%include "snappy.asm"
%endif


%if _EXODECR
	%include "exodecr.asm"
%endif


%if _X
	%include "x.asm"
%endif


%if _HEATSHRINK
	%include "heatshr.asm"
%endif


%if _LZD
	%include "lzd.asm"
%endif


%if _LZO
	%include "lzo.asm"
%endif


%if _LZSA2
	%include "lzsa2.asm"
%endif


%if _APL
	%include "apl.asm"
%endif


%if _BZP
	%include "bzp.asm"
%endif


%if _ZEROCOMP
	%include "zerocomp.asm"
%endif


%if _MVCOMP
	%include "mvcomp.asm"
%endif


%if _LZEXEDAT
	%include "lzexedat.asm"
%endif


%if _ZX0
	%include "zx0.asm"
%endif


%if _SCAN && ! SCAN_SUPPORTED
 %error Scan not supported by this depacker method
%endif


%if _ALLOW_OVERLAPPING
		; INP:	?src, ?dst
		; OUT:	CY if error (?src < ?dst)
		;	NC if success
		; CHG:	ax, bx, cx, dx
check_pointers_not_overlapping:

 %if _SCAN
	 push word [bp + ?original_dst + 2]
	 push word [bp + ?original_dst]
	call pointer_to_linear
	xchg cx, ax
	xchg bx, dx			; bx:cx = linear ?original_dst
 %endif

%if CHECK_POINTERS_VARIABLE_DST
	 push word [bp + ?dst + 2]
	 push word [bp + ?dst]
%else
	 push es
	 push di
%endif
	call pointer_to_linear		; dx:ax = linear ?dst

 %if _SCAN
	sub ax, cx
	sbb dx, bx
	mov word [bp + ?plusdst], ax
	mov word [bp + ?plusdst + 2], dx

	 push word [bp + ?original_src + 2]
	 push word [bp + ?original_src]
	call pointer_to_linear
	xchg cx, ax
	xchg bx, dx			; bx:cx = linear ?original_src
 %else
	xchg cx, ax
	xchg bx, dx			; bx:cx = linear ?dst after write
 %endif

%if CHECK_POINTERS_VARIABLE_SRC
	 push word [bp + ?src + 2]
	 push word [bp + ?src]
%else
	 push ds
	 push si
%endif
	call pointer_to_linear		; dx:ax = linear ?src before next read

 %if _SCAN
	sub ax, cx
	sbb dx, bx
	mov word [bp + ?plussrc], ax
	mov word [bp + ?plussrc + 2], dx; = plussrc

	mov bx, word [bp + ?plusdst + 2]
	mov cx, word [bp + ?plusdst]	; = plusdst

%if 0
        plusdst = dst - dstbuffer;
        plussrc = src - srcbuffer;
        if (plusdst > plussrc) {
          bytesahead = plusdst - plussrc;
          if (bytesahead > *maxbytesahead) {
            *maxbytesahead = bytesahead;
          }
        }
%endif

	cmp bx, dx
	jne @F
	cmp cx, ax			; plusdst > plussrc ?
@@:
	jna .ret			; no -->

	sub cx, ax
	sbb bx, dx			; bytesahead = plusdst - plussrc

	cmp bx, word [bp + ?maxbytesahead + 2]
	jne @F
	cmp cx, word [bp + ?maxbytesahead]
@@:					; bytesahead > maxbytesahead ?
	jna .ret			; no -->

	mov word [bp + ?maxbytesahead + 2], bx
	mov word [bp + ?maxbytesahead], cx
					; update maxbytesahead

.ret:
	clc				; NC
 %else
	cmp dx, bx			; ?src >= ?dst ?
	jne @F
	cmp ax, cx
@@:
					; (CY) if error (src < dst)
					; (NC) if no error
 %endif
	retn
%endif

	; This leaves the lframe context created within the
	;  specific depacker's file. The above function
	;  check_pointers_not_overlapping uses the frame.
	lleave ctx


%if _SCAN
		; Pretend to copy data for scan mode. Don't actually
		;  read or write the data, just adjust registers as if.
		;
		; INP:	ds:si -> source
		;	es:di -> destination
		;	cx = amount of bytes to copy
		; OUT:	si incremented
		;	di incremented
		;	cx = 0
		; CHG:	(not even flags)
scan_rep_movsb:
	pushf
	add si, cx
	add di, cx
	xor cx, cx
	popf
disp_al_for_progress:
disp_al_counter:
disp_al:
	retn
%endif


		; INP:	ds:si = pointer
		;	es:di = pointer
		; OUT:	ds:si normalised
		;	es:di normalised
%if NEED_NORMALISE_BOTH_POINTERS
normalise_both_pointers:
	 push es
	 push di
	call normalise_pointer
	 pop di
	 pop es
%endif

normalise_dssi_pointer:
	 push ds
	 push si
	call normalise_pointer
	 pop si
	 pop ds
	retn


		; INP:	word [ss:sp + 2] = segment
		;	word [ss:sp] = offset
		;
		; Note:	Does not work correctly with pointers that point to
		;	 a HMA location. Do not use then!
normalise_pointer:
%if NEED_NORMALISE_POINTER_WITH_DISPLACEMENT
	lframe near
	lpar word,	segment
	lpar word,	offset
	lpar_return
	lenter

	cmp word [bp + ?offset], 15
	jbe .ret

	push bx
	push cx

	xor bx, bx
	xor cx, cx
	 push word [bp + ?segment]
	 push word [bp + ?offset]
	call normalise_pointer_with_displacement_bxcx
	 pop word [bp + ?offset]
	 pop word [bp + ?segment]

	pop cx
	pop bx
.ret:
	lleave
	lret


		; INP:	word [ss:sp + 2] = segment
		;	word [ss:sp] = offset
		;	bx:cx = add/sub displacement
		; OUT:	CY if the displacement carries
		;	NC if not
normalise_pointer_with_displacement_bxcx:
%endif
	lframe near
	lpar word,	segment
	lpar word,	offset
	lpar_return
	lenter

%ifn NEED_NORMALISE_POINTER_WITH_DISPLACEMENT
	cmp word [bp + ?offset], 15
	jbe .ret
%endif

	push ax
	push cx
	push dx

	 push word [bp + ?segment]
	 push word [bp + ?offset]
	call pointer_to_linear

%if NEED_NORMALISE_POINTER_WITH_DISPLACEMENT
	; push bx
	; 				; sign-extend cx into bx:cx
	; cmp cx, 8000h			; CY if < 8000h (NC if negative)
	; cmc				; NC if positive
	; sbb bx, bx			; 0 if was NC, -1 if was CY

	add cx, ax
	adc dx, bx			; dx:cx = dx:ax + bx:cx
	; pop bx
	lahf				; ah = flags
%else
	xchg ax, cx
%endif

%if 0
		; Adds in HMA support for this function. Not currently used.
	cmp dx, 10h			; dx:ax >= 10_0000h ?
	jb @F				; no, linear-to-pointer normally -->
	; ja .error

	add cx, 10h
	; jc .error
	mov word [bp + ?offset], cx
	or word [bp + ?segment], -1
	jmp .return
@@:
%endif

	push bx
	mov bx, cx
	and cx, 15
	mov word [bp + ?offset], cx

	mov cl, 4
@@:
	shr dx, 1
	rcr bx, 1
	loop @B

	mov word [bp + ?segment], bx
	pop bx

	; test dx, dx
	; jnz .error

.return:

%if NEED_NORMALISE_POINTER_WITH_DISPLACEMENT
	sahf				; restore flags from ah
%endif
	pop dx
	pop cx
	pop ax
%ifn NEED_NORMALISE_POINTER_WITH_DISPLACEMENT
.ret:
%endif
	lleave
	lret


		; INP:	word [ss:sp + 2] = segment
		;	word [ss:sp] = offset
		; OUT:	dx:ax = linear address
pointer_to_linear:
	lframe near
	lpar word,	segment
	lpar word,	offset
	lenter

	mov ax, word [bp + ?segment]
	xor dx, dx
	push cx
	mov cx, 4
@@:
	shl ax, 1
	rcl dx, 1
	loop @B

	add ax, word [bp + ?offset]
	adc dx, cx			; cx = 0 here
	pop cx

	lleave
	lret


[list -]
%ifn _SCAN
[list +]

%if _PASSLCFG
	align 16
transfer_lcfg_block:
	times lcfg.size nop
%endif
	align 16
init1_end:


	usesection INIT0
%if _TEST_PROGRAM
init0_msg:
%if (_INCLUDE_UNCOMPRESSED && ! _INCLUDE_UNCOMPRESSED_IN_IMAGE) || _RELOAD_FILE
.error_stderr_file:	db "Error: Unable to open own executable file.",13,10
.error_stderr_file.length equ $ - .error_stderr_file
%endif
.error_stderr:	db "Error: Not enough memory allocated.",13,10
.error_stderr.length: equ $ - .error_stderr
.error_c_stdout:
.error_stdout:	db "0"
%if 0
		_autodigits paras(_TEST_PROGRAM_DECOMPRESSED_SIZE \
				+ (payload_end - payload) \
				+ (init1_end - init1_start) \
				+ ADDITIONAL_MEMORY \
				)
%endif
		db 13,10
.error_c_stdout.length: equ $ - .error_c_stdout
.error_stdout.length: equ $ - .error_stdout

	align 1024
%if ($ - $$) != 1024
 %error Wrong INIT0 size
%endif
%endif

	align 16
init0_end:


%assign num (init1_end - init1_start) + (init0_end - init0_start)
%if _BRIEFLZ
%define which iniblz
%elif _LZ4
%define which inilz4
%elif _SNAPPY
%define which inisz
%elif _EXODECR
%define which iniexo
%elif _X
%define which inix
%elif _HEATSHRINK
%define which inihs
%elif _LZD
%define which inilz
%elif _LZO
%define which inilzo
%elif _LZSA2
%define which inilzsa2
%elif _APL
%define which iniapl
%elif _BZP
%define which inibzp
%elif _ZEROCOMP
%define which inizero
%elif _MVCOMP
%define which inimv
%elif _LZEXEDAT
%define which inilzexe
%elif _ZX0
%define which inizx0
%endif
%warning which: num bytes used for depacker


%if _TEST_PROGRAM
	addsection INIT2, align=16 follows=INIT1 vstart=0
init2_start:
		; si => after PSP
		; cs => INIT2
		; psp, free, payload, init1, init2, payload space, stack
		;
		; The correct allocation for the test program
		;  is image size (init0, payload, init1, init2)
		;  minus init0 plus compressed payload size
		;  plus decompressed size plus stack. For
		;  simplicity, init0 subtraction may be skipped.

		; ss:sp -> word amount repetitions, word ax
		; bx = 1 if A mode test,
		;	8001h if B mode test,
		;	4001h if C mode test
	push bx			; push into ?whichtest

	lframe 0
%if (_INCLUDE_UNCOMPRESSED && ! _INCLUDE_UNCOMPRESSED_IN_IMAGE) || _RELOAD_FILE
	lpar word,	handle
%endif
	lpar word,	repetitions
	lpar word,	whichtest
%if _RELOAD_XMS
 	lvar dword, xmsentry
 	lvar word, xmshandle
%endif
%if _INCLUDE_UNCOMPRESSED && ! _INCLUDE_UNCOMPRESSED_IN_IMAGE
	lequ 128,	buffersize
	lvar ?buffersize,	buffer
%endif
	lenter

%if _RELOAD_FILE && _RELOAD_XMS
	or word [bp + ?xmshandle], -1
%endif

%if _USESCAN
doscan:
	push si
	mov ax, cs
	sub ax, ( (init1_end - init1_start) \
		+ (payload_end - payload) \
		) >> 4		; => payload source for first run
	mov ds, ax
	xor si, si

	lframe 0, nested
	lenter
	lvar dword, progressticks
	 push si
	 push si
	lvar dword, maxbytesahead
	 push si
	 push si
	lvar dword, depackedsize
	 push si
	 push si		; stack variables used by scan

	mov bx, 1		; pretend exe mode
	mov cx, (payload.end - payload) & 0FFFFh
%if (payload.end - payload) >> 16
	mov dx, (payload.end - payload) >> 16	; = length of source
%else
	xor dx, dx
%endif
	mov ax, -1		; pretend no kernel clamp
	call scan
		; CF, stack variables written
	push cs
	pop ds
	jc .fail

	mov bx, init2_msg.scan.success
	call init2_error_disp_counted

	pop ax
	pop dx			; depacked size
	call init2_error_decdword

	mov bx, init2_msg.scan.1
	call init2_error_disp_counted

	mov ax, (payload.end - payload) & 0FFFFh
%if (payload.end - payload) >> 16
	mov dx, (payload.end - payload) >> 16	; = length of source
%else
	xor dx, dx
%endif
	call init2_error_decdword

	mov bx, init2_msg.scan.2
	call init2_error_disp_counted

	pop ax
	pop dx			; maxbytesahead
	call init2_error_decdword
	add ax, 15
	adc dx, 0		; += 15
	mov cx, 4
@@:
	shr dx, 1
	rcr ax, 1
	loop @B			; >>= 4

	test dx, dx
	jz @F
	mov ax, -1
@@:
	xchg si, ax		; si = maximum paras ahead

	mov bx, init2_msg.scan.3
	call init2_error_disp_counted

	mov ax, si
	call init2_error_decword

	mov bx, init2_msg.scan.4
	call init2_error_disp_counted

	add si, paras( (init1_end - init1_start) \
			+ (payload_end - payload) )
	mov ax, si		; = decompression size
	call init2_error_decword

	mov bx, init2_msg.scan.5
	call init2_error_disp_counted

	pop ax
	pop dx			; progress ticks
	call init2_error_decdword

	mov bx, init2_msg.scan.6
	call init2_error_disp_counted

	xchg ax, si		; ax = decompression size
	jmp @F

.fail:
	mov bx, init2_msg.scan.fail
	call init2_error_disp_counted

	mov ax, -1
@@:

	lleave
	pop si

init2_scan_done:
	lvar word, scansizeresult
	 push ax
%endif

	mov dx, word [bp + ?repetitions]
	cmp dx, -1
	jne @F

.cmdline_error:
%if _DEBUG0
	mov bx, -1
%endif
	mov dx, init2_msg.cmdline_error
	mov cx, init2_msg.cmdline_error.length
	jmp init2_error


@@:
	testopt [bp + ?whichtest], 4000h
	jnz .a_or_c
	testopt [bp + ?whichtest], 8000h
	jz .a_or_c
.b:
	test dx, dx
	jz .cmdline_error
	jmp @F

.a_or_c:
	test dx, dx
	jnz .cmdline_error
@@:

%if _RELOAD_XMS
	push si
	mov ax, 4300h
	int 2Fh
	cmp al, 80h
%if _RELOAD_FILE
	jne .noxms
%else
	jne init2_error_xms
%endif
	mov ax, 4310h
	int 2Fh
	mov word [bp + ?xmsentry], bx
	mov word [bp + ?xmsentry + 2], es
	mov ah, 09h
	mov dx, KiB(payload_end - payload)
	call far [bp + ?xmsentry]
	cmp ax, 1
%if _RELOAD_FILE
	jne .noxms
%else
	jne init2_error_xms
%endif
	mov word [bp + ?xmshandle], dx
	mov ax, cs
	sub ax, ( (init1_end - init1_start) \
		+ (payload_end - payload) \
		) >> 4		; => payload source for first run
	 push cs
	 pop ds
	mov si, init2_xmsm_to_save
	mov word [si + XMSM.dsthdl], dx
	mov word [si + XMSM.srcadr + 2], ax
%ifn _RELOAD_FILE
	push ax
%endif
	mov ah, 0Bh
	call far [bp + ?xmsentry]
	cmp ax, 1
	jne init2_error_xms_free
%ifn _RELOAD_FILE
	pop ax			; => payload
%else
.noxms:
	mov ax, cs
	sub ax, ( (init1_end - init1_start) \
		+ (payload_end - payload) \
		) >> 4		; => payload source for first run
@@:
%endif
	pop si
%elif _RELOAD_FILE
	mov ax, cs
	sub ax, ( (init1_end - init1_start) \
		+ (payload_end - payload) \
		) >> 4		; => payload source for first run
%else
	mov dx, cs
	add dx, (init2_end - init2_start) >> 4
				; => payload saving area
	mov ax, cs
	sub ax, ( (init1_end - init1_start) \
		+ (payload_end - payload) \
		) >> 4		; => payload source for first run
	mov cx, (payload_end - payload) >> 4
	call init2_movp		; copy payload to payload saving area
%endif
		; We save away the payload here because a failure
		;  to decompress generally overwrites part of that
		;  payload which was used as source.

	mov dx, ax		; dx => payload source to use
	mov ax, cs
	sub ax, (init1_end - init1_start) >> 4
				; ax => INIT1
	mov bx, 1		; say we're in EXE mode
	push dx
	push ax
	push si			; si => target
	 push cs
	 call .transfer		; call decompression
	pop si
	pop ax
	pop dx
		; Returns here after decompression.
		; CY if error.
	jnc @F

	mov dx, init2_msg.initial_error
	mov cx, init2_msg.initial_error.length
	jmp init2_error_free

@@:
%if _INCLUDE_UNCOMPRESSED
 %if _INCLUDE_UNCOMPRESSED_IN_IMAGE
payload_uncompressed_size equ payload_uncompressed.end - payload_uncompressed
 %else
payload_uncompressed_size equ _TEST_PROGRAM_DECOMPRESSED_SIZE
 %endif
	call checkdecompressed
	je @F

%if _WRITE_WRONG_FILE
	call writefiles
%endif

%if _DEBUG0
	mov bx, -1
%endif
	mov dx, init2_msg.initial_error_2
	mov cx, init2_msg.initial_error_2.length
	jmp init2_error_free

@@:
%endif

	testopt [bp + ?whichtest], 4000h
	jz @F
	mov ax, cs
	sub ax, (init1_end - init1_start) >> 4
				; ax => INIT1
	mov es, ax
	mov ax, word [es:init1_c_mode_counter]
	call init2_disp_ax_dec
	mov al, 13
	call init2_disp_al
	mov al, 10
	call init2_disp_al
%if _RELOAD_XMS
	call freexms
%endif
	mov ax, 4C00h
	int 21h

@@:
	lvar word,	upperbound
	 push dx
	lvar word,	lowerbound
	 push si
	lvar word,	current_init1
	 push ax

%if _TEST_PROGRESS
	mov dx, init2_msg.progress.1
	mov cx, init2_msg.progress.1.length
.loop:
	push cs
	pop ds
	mov bx, 2
	mov ah, 40h
	int 21h
%else
.loop:
%endif

	mov dx, [bp + ?upperbound]

	testopt [bp + ?whichtest], 8000h
	jz @F

	dec word [bp + ?repetitions]
	jnz .test_b_skip_bound

%if _TEST_PROGRESS
	push cs
	pop ds
	mov dx, init2_msg.progress.linebreak
	mov cx, init2_msg.progress.linebreak.length
	mov bx, 2
	mov ah, 40h
	int 21h
%endif
%if _RELOAD_XMS
	call freexms
%endif
	mov ax, 4C00h
	int 21h


@@:
	sub dx, [bp + ?lowerbound]
	jz .found
	shr dx, 1
		; Rounding down, so that we never retry upper bound.
		;  The upper bound is known to be working.
	add dx, [bp + ?lowerbound]

.test_b_skip_bound:
	push dx
	add dx, (payload_end - payload) >> 4
	mov ax, [bp + ?current_init1]
	mov cx, (init1_end - init1_start) >> 4
	call init2_movp
	mov [bp + ?current_init1], dx
	pop dx

%if _RELOAD_XMS
	mov ax, [bp + ?xmshandle]
 %if _RELOAD_FILE
	cmp ax, -1
	je .restore_no_xms
 %endif
	push si
	 push cs
	 pop ds
	mov si, init2_xmsm_from_save
	mov word [si + XMSM.srchdl], ax
	mov word [si + XMSM.dstadr + 2], dx
	mov ah, 0Bh
	call far [bp + ?xmsentry]
	cmp ax, 1
	jne init2_error_xms_free
	pop si
 %if _RELOAD_FILE
	jmp .restore_done
 %endif
%endif
%if _RELOAD_FILE
.restore_no_xms:
size_compressed equ (payload.end - payload)
	push dx
	mov ds, dx
	mov cx, ((- size_compressed) >> 16) & 0FFFFh
	mov dx, (- size_compressed) & 0FFFFh
	mov ax, 4202h
	mov bx, [bp + ?handle]
	int 21h
	jc init2_error_file
	mov dx, size_compressed >> 16
	mov ax, size_compressed & 0FFFFh
@@:
	mov cx, 0FF00h
	test dx, dx
	jnz @F
	cmp ax, cx
	jae @F
	mov cx, ax
@@:
	sub ax, cx
	sbb dx, 0
	push dx
	push ax
	xor dx, dx
	mov ah, 3Fh
	int 21h
	jc init2_error_file
	cmp ax, cx
	jne init2_error_file
	mov dx, ds
	add dx, 0FF0h
	mov ds, dx
	pop ax
	pop dx
	mov cx, ax
	or cx, dx
	jnz @BB
	pop dx
.restore_done:
%endif
%ifn _RELOAD_XMS || _RELOAD_FILE
	mov ax, cs
	add ax, (init2_end - init2_start) >> 4
				; => payload in saving area
	mov cx, (payload_end - payload) >> 4
	call init2_movp		; copy payload from payload saving area
%endif
		; dx => source
	mov ax, [bp + ?current_init1]
	mov bx, 1
	push dx
	push si
	 push cs
	 call .transfer
	pop si
	pop dx
		; Returns here after decompression.
		; CY if error.
	jnc @F

	testopt [bp + ?whichtest], 8000h
	jnz .test_b_fail

		; error: this attempt is one below the new lower bound
	inc dx
	mov word [bp + ?lowerbound], dx

%if _TEST_PROGRESS
	mov dx, init2_msg.progress.fail
	mov cx, init2_msg.progress.fail.length
%endif
	jmp .loop

@@:
%if _INCLUDE_UNCOMPRESSED
	call checkdecompressed
	je @F

%if _WRITE_WRONG_FILE
	call writefiles
%endif

.test_b_fail:
%if _TEST_PROGRESS
	push cs
	pop ds
	mov dx, init2_msg.progress.linebreak
	mov cx, init2_msg.progress.linebreak.length
	mov bx, 2
	mov ah, 40h
	int 21h
%endif
%if _DEBUG0
	mov bx, -2
%endif
	mov dx, init2_msg.subsequent_error_2
	mov cx, init2_msg.subsequent_error_2.length
	jmp init2_error_free

@@:
%endif
		; success: this attempt is the new upper bound
	mov word [bp + ?upperbound], dx
%if _TEST_PROGRESS
	mov dx, init2_msg.progress.success
	mov cx, init2_msg.progress.success.length
%endif
	jmp .loop

.found:
%if _TEST_PROGRESS
	push cs
	pop ds
	mov dx, init2_msg.progress.linebreak
	mov cx, init2_msg.progress.linebreak.length
	mov bx, 2
	mov ah, 40h
	int 21h
%endif
	mov ax, word [bp + ?upperbound]
	sub ax, si		; = how many paragraphs in buffer before source
	add ax, paras( (init1_end - init1_start) \
			+ (payload_end - payload) )
				; = how many paragraphs needed for process
	call init2_disp_ax_dec
	mov al, 13
	call init2_disp_al
	mov al, 10
	call init2_disp_al
%if _RELOAD_XMS
	call freexms
%endif
	mov ax, 4C00h
	int 21h


.transfer:
	xor di, di
	push di			; placeholder ax value on stack
	push ax			; INIT1 segment
	push di			; zero = init1_start
	retf			; transfer to INIT1:init1_start


%if _USESCAN
	align 16, nop
scan:
	noteincbin _SCANBINARY, "scan.lst"
%endif


%if _INCLUDE_UNCOMPRESSED


%if _WRITE_WRONG_FILE
		; INP:	si => decompressed image
		;	payload_uncompressed_size = size
		;	! _INCLUDE_UNCOMPRESSED_IN_IMAGE:
		;	 word [bp + ?handle] = file handle
		;	 [bp + ?buffer] = ?buffersize buffer
		; OUT:	WRONG.BIN contains what we decompressed
		;	WRONG2.BIN contains expected payload
		; CHG:	ds, si, ax, bx, cx, dx
		; STT:	UP
writefiles:
	push cs
	pop ds
	mov dx, init2_msg.wrong_file_name
	xor cx, cx
	mov ah, 3Ch
	int 21h
	jc .notfile

	mov bx, ax
	mov cx, payload_uncompressed_size >> 4
	xor dx, dx
.loopfile:
	mov ds, si
	mov ah, 40h
	push cx
	mov cx, 16
	int 21h
	pop cx
	inc si
	loop .loopfile

	mov ds, si
	mov cx, payload_uncompressed_size & 15
	mov ah, 40h
	int 21h

	mov ah, 3Eh
	int 21h

.notfile:

	push cs
	pop ds
	mov dx, init2_msg.wrong_file_name2
	xor cx, cx
	mov ah, 3Ch
	int 21h
	jc .notfile2

%if _INCLUDE_UNCOMPRESSED_IN_IMAGE
	mov bx, ax
	mov cx, payload_uncompressed_size >> 4
	mov si, cs
	add si, (payload_uncompressed - init2_start) >> 4
	xor dx, dx
.loopfile2:
	mov ds, si
	mov ah, 40h
	push cx
	mov cx, 16
	int 21h
	pop cx
	inc si
	loop .loopfile2

	mov ds, si
	mov cx, payload_uncompressed_size & 15
	mov ah, 40h
	int 21h

	mov ah, 3Eh
	int 21h
%else
	xchg si, ax

%if _RELOAD_FILE
	mov cx, ((- size_compressed_plus_uncompressed) >> 16) & 0FFFFh
	mov dx, (- size_compressed_plus_uncompressed) & 0FFFFh
%else
	mov cx, ((- payload_uncompressed_size) >> 16) & 0FFFFh
	mov dx, (- payload_uncompressed_size) & 0FFFFh
%endif
	mov ax, 4202h
	mov bx, [bp + ?handle]
	int 21h
	jc .closefile2

	push ss
	pop ds
	lea dx, [bp + ?buffer]

%if payload_uncompressed_size == 0
 %error Empty payload not allowed
%endif
%if (payload_uncompressed_size / ?buffersize) != 0
	mov cx, payload_uncompressed_size / ?buffersize
%if ?buffersize == 0 || (?buffersize & 15) != 0
 %error Unexpected layout
%endif
.loop:
	push cx
	mov cx, ?buffersize
	call transferchunk
	pop cx
	jc .closefile2
	loop .loop
%endif
%if (payload_uncompressed_size % ?buffersize) != 0
	mov cx, payload_uncompressed_size % ?buffersize
	call transferchunk
%endif

.closefile2:
	mov bx, si
	mov ah, 3Eh
	int 21h
%endif

.notfile2:
	retn

%if ! _INCLUDE_UNCOMPRESSED_IN_IMAGE
		; INP:	ds:dx -> buffer
		;	cx = size to transfer, must fit in buffer
		;	?handle = source file handle
		;	si = destination file handle
		; OUT:	NC if success
		;	CY if error
		; CHG:	ax, bx
		; STT:	UP
transferchunk:
	mov bx, word [bp + ?handle]
	mov ah, 3Fh
	int 21h
	jc .ret
	cmp ax, cx
	stc
	jne .ret		; if partial read --> (CY)
	mov bx, si
	mov ah, 40h
	int 21h
	jc .ret
	cmp ax, cx
	je .ret			; if not partial write --> (NC)
	stc
.ret:
	retn
%endif

%endif


		; INP:	si => decompressed image
		;	payload_uncompressed_size = size
		;	! _INCLUDE_UNCOMPRESSED_IN_IMAGE:
		;	 word [bp + ?handle] = file handle
		;	 [bp + ?buffer] = ?buffersize buffer
		; OUT:	ZR if matching
		;	NZ if mismatching
		; CHG:	es, ds, di, bx, cx
		; STT:	UP
checkdecompressed:
	push ax
	push dx
	push si
%if _INCLUDE_UNCOMPRESSED_IN_IMAGE
%if _PAYLOAD_KERNEL_MAX_PARAS
	mov cx, _PAYLOAD_KERNEL_MAX_PARAS
	mov bx, 0
%else
	mov cx, payload_uncompressed_size >> 4
	mov bx, payload_uncompressed_size & 15
%endif
	mov di, cs
	add di, (payload_uncompressed - init2_start) >> 4
	jcxz .end
.loop:
	push cx
	mov cx, 8
	mov ds, si
	mov es, di
	inc si
	inc di
	push si
	push di
	xor si, si
	xor di, di
	repe cmpsw
	pop di
	pop si
	pop cx
	jne .ret
	loop .loop
.end:
	mov ds, si
	mov es, di
	xor si, si
	xor di, di		; (ZR)
	mov cx, bx
	repe cmpsb
%else
%if _RELOAD_FILE
size_compressed_plus_uncompressed equ \
 payload_uncompressed_size + (payload.end - payload)
	mov cx, ((- size_compressed_plus_uncompressed) >> 16) & 0FFFFh
	mov dx, (- size_compressed_plus_uncompressed) & 0FFFFh
%else
	mov cx, ((- payload_uncompressed_size) >> 16) & 0FFFFh
	mov dx, (- payload_uncompressed_size) & 0FFFFh
%endif
	mov ax, 4202h
	mov bx, [bp + ?handle]
	int 21h
	jc .error
%if payload_uncompressed_size == 0
 %error Empty payload not allowed
%endif
%if (payload_uncompressed_size / ?buffersize) != 0
	mov cx, payload_uncompressed_size / ?buffersize
%if ?buffersize == 0 || (?buffersize & 15) != 0
 %error Unexpected layout
%endif
.loop:
	push cx
	mov cx, ?buffersize
	call comparechunk
	pop cx
	jne .ret
	loop .loop
%endif
%if (payload_uncompressed_size % ?buffersize) != 0
	mov cx, payload_uncompressed_size % ?buffersize
	call comparechunk
%endif
%endif
.ret:
	pop si
	pop dx
	pop ax
	retn

%if ! _INCLUDE_UNCOMPRESSED_IN_IMAGE
.error:
	or al, 1			; NZ
	jmp .ret
%endif
%endif


%if ! _INCLUDE_UNCOMPRESSED_IN_IMAGE
		; INP:	?buffer -> ?buffersize buffer
		;	cx = amount of bytes, 0 < cx <= ?buffersize
		;	si => chunk
		;	?handle = handle
		;	seek -> chunk
		; OUT:	NZ if mismatch or error
		;	ZR else,
		;	 si => next chunk (assumes full chunk)
		; CHG:	ds, es, di, ax, bx, cx, dx
		; STT:	UP
comparechunk:
	push ss
	pop ds
	lea dx, [bp + ?buffer]
	mov bx, [bp + ?handle]
	mov ah, 3Fh
	int 21h
	jc .error
	cmp ax, cx
	jne .error
	mov es, si
	add si, ?buffersize / 16
	push si
	xor di, di
	mov si, dx
	repe cmpsb
	pop si
.ret:
	retn

.error:
	or al, 1			; NZ
	retn
%endif

%if _RELOAD_XMS
freexms:
	push ax
	push bx
	push dx
	mov dx, -1
	xchg dx, [bp + ?xmshandle]
%if _RELOAD_FILE
	cmp dx, -1
	je @F
%endif
	mov ah, 0Ah
	call far [bp + ?xmsentry]
@@:
	pop dx
	pop bx
	pop ax
	retn

init2_error_xms_free:
	call freexms
init2_error_xms:
	mov dx, init2_msg.xms_error
	mov cx, init2_msg.xms_error.length
	jmp init2_error
%endif

%if _RELOAD_FILE
init2_error_file:
	mov dx, init2_msg.file_error
	mov cx, init2_msg.file_error.length
%endif

init2_error_free:
%if _RELOAD_XMS
	call freexms
%endif
init2_error:
%if _DEBUG0
	push bx
%endif
	push cs
	pop ds
	mov bx, 2
	mov ah, 40h
	int 21h

%if _DEBUG0
	mov dx, init2_msg.rc
	mov cx, init2_msg.rc.length
	mov bx, 2
	mov ah, 40h
	int 21h
	pop ax
	call init2_error_disp_ax_hex
	mov dx, init2_msg.linebreak
	mov cx, init2_msg.linebreak.length
	mov bx, 2
	mov ah, 40h
	int 21h
%endif

	testopt [bp + ?whichtest], 4000h
	jz @F
	mov dx, init2_msg.error_c_stdout
	mov cx, init2_msg.error_c_stdout.length
	jmp @FF
@@:
	testopt [bp + ?whichtest], 8000h
	jnz @FF
	mov dx, init2_msg.error_stdout
	mov cx, init2_msg.error_stdout.length
@@:
	mov bx, 1
	mov ah, 40h
	int 21h
@@:
	mov ax, 4CFFh
	int 21h

	lleave ctx


%if _DEBUG0 || _USESCAN
init2_error_disp_ax_hex:	; ax
		xchg al,ah
		call init2_error_disp_al_hex	; display former ah
		xchg al,ah			;  and fall trough for al
init2_error_disp_al_hex:	; al
		push cx
		mov cl,4
		ror al,cl
		call init2_error_disp_al_lownibble_hex
						; display former high-nibble
		rol al,cl
		pop cx
						;  and fall trough for low-nibble
init2_error_disp_al_lownibble_hex:
		push ax			 ; save ax for call return
		and al,00001111b		; high nibble must be zero
		add al,'0'			; if number is 0-9, now it's the correct character
		cmp al,'9'
		jna .decimalnum		 ; if we get decimal number with this, ok -->
		add al,7			;  otherwise, add 7 and we are inside our alphabet
 .decimalnum:
		call init2_error_disp_al
		pop ax
		retn


init2_error_disp_al:
	push dx
	push cx
	push bx
	push ax
	mov dx, sp
	push ds
	 push ss
	 pop ds
	mov cx, 1
	mov bx, 2
	mov ah, 40h
	int 21h
	pop ds
	pop ax
	pop bx
	pop cx
	pop dx
	retn
%endif


init2_disp_al:
	push dx
	push ax
	mov dl, al
	mov ah, 2
	int 21h
	pop ax
	pop dx
	retn


%if _USESCAN
init2_error_disp_counted:
	push ax
	push bx
	push cx
	push dx
	xor cx, cx
	mov cl, [bx]
	lea dx, [bx + 1]
	mov ah, 40h
	mov bx, 2
	int 21h
	pop dx
	pop cx
	pop bx
	pop ax
	retn


init2_error_decword:
	push dx
	xor dx, dx
	call init2_error_decdword
	pop dx
	retn


init2_error_decdword:
	push cx
	xor cx, cx
	call init2_error_dec_dword_minwidth
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
init2_error_dec_dword_minwidth:
	lframe near
	lequ 10,	bufferlen
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

	mov ah, 40h
	mov bx, 2		; stderr
	push ds
	 push ss
	 pop ds
	int 21h
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
%endif


		; Display number in ax decimal
		;
		; INP:	ax = number
		; OUT:	displayed using Int21.02
		; CHG:	none
init2_disp_ax_dec:			; ax (no leading zeros)
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
		call init2_disp_al
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
		call init2_disp_al		; display result
 .leadingzero:
		pop ax				; remainder
		pop dx
		retn


init2_msg:
%if _USESCAN
.scan.success:		counted "Note: Scan depack="
.scan.1:		counted " pack="
.scan.2:		counted " ahead="
.scan.3:		counted ",para="
.scan.4:		counted " alloc="
.scan.5:		counted " progress="
.scan.6:		counted 13,10
.scan.fail:		counted "Note: Scan failure",13,10
%endif
%if _TEST_PROGRESS
.progress.1:		db "Info: 1"
.progress.1.length: equ $ - .progress.1
.progress.fail:		db "F"
.progress.fail.length: equ $ - .progress.fail
.progress.success:	db "S"
.progress.success.length: equ $ - .progress.success
.progress.linebreak:	db 13,10
.progress.linebreak.length: equ $ - .progress.linebreak
%endif
%if _WRITE_WRONG_FILE
.wrong_file_name:	asciz "WRONG.BIN"
.wrong_file_name2:	asciz "WRONG2.BIN"
%endif
.initial_error:	db "Error: Test program failed to decompress with full buffer."
.linebreak:	db 13,10
.initial_error.length: equ $ - .initial_error
.linebreak.length: equ $ - .linebreak
%if _DEBUG0
.rc:	db "Error: Failure code="
.rc.length: equ $ - .rc
%endif
%if _INCLUDE_UNCOMPRESSED
.initial_error_2:	db "Error: Test program decompressed wrongly with full buffer.",13,10
.initial_error_2.length: equ $ - .initial_error_2
.subsequent_error_2:	db "Error: Test program decompressed wrongly during test.",13,10
.subsequent_error_2.length: equ $ - .subsequent_error_2
%endif
.cmdline_error:	db "Error: Invalid command line input.",13,10
.cmdline_error.length: equ $ - .cmdline_error
%if _RELOAD_XMS
.xms_error:	db "Error: XMS failure.",13,10
.xms_error.length: equ $ - .xms_error
%endif
%if _RELOAD_FILE
.file_error:	db "Error: File read failure.",13,10
.file_error.length: equ $ - .file_error
%endif

.error_c_stdout:
.error_stdout:	db "0"
%if 0
		_autodigits paras(_TEST_PROGRAM_DECOMPRESSED_SIZE \
				+ (payload_end - payload) \
				+ (init1_end - init1_start) \
				+ ADDITIONAL_MEMORY \
				)
%endif
		db 13,10
.error_c_stdout.length: equ $ - .error_c_stdout
.error_stdout.length: equ $ - .error_stdout


		; Move paragraphs
		;
		; INP:	ax => source
		;	dx => destination
		;	cx = number of paragraphs
		; CHG:	-
		; OUT:	ax and dx unchanged
		; Note:	Doesn't work correctly on HMA; doesn't always wrap to LMA either.
		;	Do not provide a wrapped/HMA source or destination!
init2_movp:
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

		; Refer to comment in init0_movp.
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


	align 4
%if _RELOAD_XMS
init2_xmsm_from_save:
	istruc XMSM
at XMSM.size_,	dd payload_end - payload
	iend
init2_xmsm_to_save:
	istruc XMSM
at XMSM.size_,	dd payload_end - payload
	iend
%endif

	align 16

%if _INCLUDE_UNCOMPRESSED && _INCLUDE_UNCOMPRESSED_IN_IMAGE
	strdef UNCOMPRESSED_FILE, "lDOSLOAD.BIN"
payload_uncompressed:
	incbin _UNCOMPRESSED_FILE
.end:
	db 38
	align 16, db 38
%endif
init2_end:
%endif


%endif	; _SCAN
[list +]
