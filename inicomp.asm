
%if 0

lDOS iniload packed payload
 by C. Masloch, 2018-2020

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

	numdef DEBUG0		; use errordata to generate an error code
	numdef DEBUG1		; dump_stack_frame after an error occurred
	numdef DEBUG2		; dump_stack_frame before blz_depack_safe call
	numdef DEBUG3		; dump_stack_frame at start of blz_depack_safe

	numdef ALLOW_OVERLAPPING,	1	; allow overlapping src and dst
	numdef TEST_PROGRAM,		0
	numdef TEST_PROGRAM_DECOMPRESSED_SIZE,		0,0
%if _TEST_PROGRAM && ! _TEST_PROGRAM_DECOMPRESSED_SIZE
 %error Test program has to learn of decompressed size.
%endif
	numdef TEST_PROGRESS,	0

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
	numdef DEVICE,			0
	gendef DEVICE_NAME,		""
	numdef DEVICE_ATTRIBUTE,	8000h
	numdef DEVICE_ZERO_ENTRYPOINT,	0
%if _DEVICE
 %ifidn _DEVICE_NAME, ""
  %error Device name must be set
 %endif
%endif

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
%if (!!_BRIEFLZ + !!_LZ4 + !!_SNAPPY + !!_EXODECR + !!_X + !!_HEATSHRINK \
	+ !!_LZD + !!_LZO + !!_LZSA2 + !!_APL + !!_BZP) != 1
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
%endif
	numdef PAYLOAD_KERNEL_MAX_PARAS,	0, 0
%if _PAYLOAD_KERNEL_MAX_PARAS && ! _IMAGE_EXE
 %error Kernel mode max paras requires building dual-mode executable
%endif
	numdef COUNTER,		0, 32
%if (_COUNTER - 1) & _COUNTER
 %error COUNTER must be a power of two
%endif


	cpu 8086
	section INIT0 start=0 vstart=0
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
%endif


j_zero_entrypoint:

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
	xor bx, bx		; 0 = kernel mode
	push ax
	mov ax, cs
	add ax, (init0_end - init0_start) >> 4
	mov dx, word [ bp + ldLoadTop ]	; => after end of available space
	mov si, 60h		; => destination
	jmp init0_common

 %if _IMAGE_EXE
	align 64, nop
init0_exe_entry:
		; NOTE:	This part is called with ip = 256 + 64, cs = PSP.
%if ($ - $$) != 64
 %error Wrong EXE mode entrypoint
%endif
	mov bx, 1		; EXE mode
	push ax
  %if _TEST_PROGRAM
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
.invalid:
	mov dx, -1		; invalid
	jmp .end

.a:
	and bh, ~ 80h
	jmp .

.b:
	or bh, 80h
	jmp .

.end:
	push dx
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
	sub dx, ( (payload_end - payload) ) >> 4
	jc .error
	mov cx, ( (payload_end - payload) \
		+ (init1_end - init1_start) \
		+ (init2_end - init2_start) \
		) >> 4
	sub dx, cx
	jc .error
	cmp dx, ax
	jb .error
%else
	mov cx, ( (payload_end - payload) \
		+ (init1_end - init1_start) \
		) >> 4
				; cx = amount paragraphs in payload + INIT1
	sub dx, cx		; => destination for payload + INIT1
				;  (highest possible spot in available memory)
%endif
	push si			; preserve destination
	call init0_movp		; move up payload + INIT1
	pop si
%else
	cld
	mov ax, cs
	add ax, (init0_end - init0_start) >> 4
	mov cx, ( (payload_end - payload) \
		+ (init1_end - init1_start) \
		) >> 4
	mov dx, word [ bp + ldLoadTop ]
	sub dx, cx
	call init0_movp
%endif

	mov ax, dx		; => payload
%if _TEST_PROGRAM
	add ax, ( \
		+ (payload_end - payload) \
		+ (init1_end - init1_start) \
		) >> 4		; => INIT2
%else
	add ax, ( \
		+ (payload_end - payload) \
		) >> 4		; => INIT1
%endif
	xor cx, cx
	push ax
	push cx
	retf			; jump to relocated INIT1:init1_start
				;  or INIT2:init2_start


%if _TEST_PROGRAM
.error:
	mov di, bx

	push cs
	pop ds
	mov dx, init0_msg.error_stderr + 256
	mov cx, init0_msg.error_stderr.length
	mov bx, 2
	mov ah, 40h
	int 21h

	test di, 8000h
	jnz @F
	mov dx, init0_msg.error_stdout + 256
	mov cx, init0_msg.error_stdout.length
	mov bx, 1
	mov ah, 40h
	int 21h
@@:
	mov ax, 4CFFh
	int 21h
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

	mov ax, word [es:bx + 14 + 2]
	xor dx, dx
	mov cx, 4
@@:
	shl ax, 1
	rcl dx, 1
	loop @B
	add ax, word [es:bx + 14]
	adc dx, 0		; dx:ax = linear address behind end

	mov cl, 4
@@:
	shr dx, 1
	rcr ax, 1
	loop @B			; ax => behind end

	mov di, cs
image_size: equ  ( (init0_end - init0_start) \
		+ (payload_end - payload) \
		+ (init1_end - init1_start) \
		)
	add di, image_size >> 4		; di => end of image

	cmp ax, di			; enough memory to hold all of us ?
	jae .have_some_memory		; yes -->

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


.have_some_memory:
	mov dx, ax		; => after end of memory
	mov bx, 2		; device mode
	push ax
	mov ax, cs
	add ax, (init0_end - init0_start) >> 4
	mov si, cs		; => destination
	jmp init0_common
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


	section PAYLOAD align=16 follows=INIT0
payload:
	incbin _PAYLOAD_FILE
.end:
	align 16, db 38
payload_end:


	section INIT1 align=16 follows=PAYLOAD vstart=0
init1_start:
		; INP:	ax = cs = INIT1
		;	dx = cs - (payload_end - payload) >> 4 => source data
		;	if kernel mode:
		;	 ss:bp -> LOADDATA and LOADSTACKVARS
		;	 ss:sp -> valid stack above [bp + ldLoadTop]
		;	 60h => destination
		;	any mode:
		;	 word [ss:sp] = value for ax
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
%else
	xor bx, bx		; always tell them it is kernel mode
%endif

%if _IMAGE_EXE
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
	jc strict short error
%endif
%if _IMAGE_EXE
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
	retf
	nop
%endif

%if _DEVICE
	test bl, 2
	jz .jmp_exe_or_kernel_mode

.jmp_device_mode:
	mov ds, si
	or word [device_header.next], -1
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
	add si, _IMAGE_EXE_CS	; = relocated cs value
%endif
	push si
	push cx
	retf			; jump to EXE mode of image

%endif
.jmp_kernel_mode:
	jmp 60h + _EXEC_SEGMENT:_EXEC_OFFSET


error:
	push cs
	pop ds
%if _DEBUG0
	mov si, msg.error_begin
	call disp_error
	xchg ax, bx			; ax = error code
	call disp_ax_hex
	mov si, msg.error_end
%else
	mov si, msg.error
%endif
	call disp_error

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
	test byte [bp - 2], 1
	jz .exit_kernel_mode

	mov ax, 4C7Fh
	int 21h

.exit_kernel_mode:
%endif
	xor ax, ax
	int 16h
	int 19h


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

disp_al:
%if _TEST_PROGRAM
	retn
%else
	push ax
%endif
	push bx
	push bp
	mov ah, 0Eh
	mov bx, 7
%if _IMAGE_EXE || _DEVICE
	push dx

	test byte [bp - 2], 1 | 2
	jz .display_kernel_mode

	xchg dx, ax				; dl = input al
	mov ah, 02h
	int 21h
	db __TEST_IMM16				; (skip int)

.display_kernel_mode:
%endif
	int 10h
%if _IMAGE_EXE
	pop dx
%endif
	pop bp
	pop bx
	pop ax
disp_error.ret:
	retn


msg:
%if _DEBUG0
.error_begin:	db "Load error: Decompression failure, code ",0
.error_end:	db "h.",13,10,0
%else
.error:		db "Load error: Decompression failure.",13,10,0
%endif


%assign NEED_NORMALISE_POINTER_WITH_DISPLACEMENT 1
%assign CHECK_POINTERS_VARIABLE_SRC 1
%assign CHECK_POINTERS_VARIABLE_DST 1

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


%if _ALLOW_OVERLAPPING
		; INP:	?src, ?dst
		; OUT:	CY if error (?src < ?dst)
		;	NC if success
		; CHG:	ax, bx, cx, dx
check_pointers_not_overlapping:
%if CHECK_POINTERS_VARIABLE_DST
	 push word [bp + ?dst + 2]
	 push word [bp + ?dst]
%else
	 push es
	 push di
%endif
	call pointer_to_linear

	xchg cx, ax
	xchg bx, dx			; bx:cx = linear ?dst after write

%if CHECK_POINTERS_VARIABLE_SRC
	 push word [bp + ?src + 2]
	 push word [bp + ?src]
%else
	 push ds
	 push si
%endif
	call pointer_to_linear		; dx:ax = linear ?src before next read

	cmp dx, bx			; ?src >= ?dst ?
	jne @F
	cmp ax, cx
@@:
					; (CY) if error (src < dst)
					; (NC) if no error
	retn
%endif

	; This leaves the lframe context created within the
	;  specific depacker's file. The above function
	;  check_pointers_not_overlapping uses the frame.
	lleave ctx


		; INP:	ds:si = pointer
		;	es:di = pointer
		; OUT:	ds:si normalised
		;	es:di normalised
normalise_both_pointers:
	 push es
	 push di
	call normalise_pointer
	 pop di
	 pop es

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


	align 16
init1_end:


	section INIT0
%if _TEST_PROGRAM
init0_msg:
.error_stderr:	db "Error: Not enough memory allocated.",13,10
.error_stderr.length: equ $ - .error_stderr
.error_stdout:	_autodigits paras(_TEST_PROGRAM_DECOMPRESSED_SIZE \
				+ (payload_end - payload) \
				+ (init1_end - init1_start) \
				+ ADDITIONAL_MEMORY \
				)
		db 13,10
.error_stdout.length: equ $ - .error_stdout

	align 512
%if ($ - $$) != 512
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
%endif
%warning which: num bytes used for depacker


%if _TEST_PROGRAM
	section INIT2 align=16 follows=INIT1 vstart=0
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
		; bx = 1 if A test, 8001h if B test
	push bx

	lframe 0
	lpar word,	repetitions
	lpar word,	whichtest
	lenter

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
	testopt [bp + ?whichtest], 8000h
	jz .a
.b:
	test dx, dx
	jz .cmdline_error
	jmp @F

.a:
	test dx, dx
	jnz .cmdline_error
@@:

	mov dx, cs
	add dx, (init2_end - init2_start) >> 4
				; => payload saving area
	mov ax, cs
	sub ax, ( (init1_end - init1_start) \
		+ (payload_end - payload) \
		) >> 4		; => payload source for first run
	mov cx, (payload_end - payload) >> 4
	call init2_movp		; copy payload to payload saving area
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
	jmp init2_error

@@:
	numdef INCLUDE_UNCOMPRESSED
	numdef WRITE_WRONG_FILE
%if _INCLUDE_UNCOMPRESSED
payload_uncompressed_size equ payload_uncompressed.end - payload_uncompressed

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
	jmp init2_error

@@:
%endif

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

	mov ax, cs
	add ax, (init2_end - init2_start) >> 4
				; => payload in saving area
	mov cx, (payload_end - payload) >> 4
	call init2_movp		; copy payload from payload saving area

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
	jmp init2_error

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
	mov ax, 4C00h
	int 21h


.transfer:
	xor di, di
	push di			; dummy ax value on stack
	push ax			; INIT1 segment
	push di			; zero = init1_start
	retf



%if _INCLUDE_UNCOMPRESSED


%if _WRITE_WRONG_FILE
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

.notfile2:
	retn
%endif

		; INP:	si => decompressed image
		; OUT:	ZR if matching
		;	NZ if mismatching
		; CHG:	es, ds, di, bx, cx
		; STT:	UP
checkdecompressed:
	push ax
	push dx
	push si
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
.ret:
	pop si
	pop dx
	pop ax
	retn
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

	testopt [bp + ?whichtest], 8000h
	jnz @F

	mov dx, init2_msg.error_stdout
	mov cx, init2_msg.error_stdout.length
	mov bx, 1
	mov ah, 40h
	int 21h
@@:
	mov ax, 4CFFh
	int 21h

	lleave ctx


%if _DEBUG0
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
.error_stdout:	_autodigits paras(_TEST_PROGRAM_DECOMPRESSED_SIZE \
				+ (payload_end - payload) \
				+ (init1_end - init1_start) \
				+ ADDITIONAL_MEMORY \
				)
		db 13,10
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


	align 16

	strdef UNCOMPRESSED_FILE, "lDOSLOAD.BIN"
%if _INCLUDE_UNCOMPRESSED
payload_uncompressed:
	incbin _UNCOMPRESSED_FILE
.end:
	db 38
	align 16, db 38
%endif
init2_end:
%endif

