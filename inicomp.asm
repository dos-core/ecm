
%if 0

lDOS iniload packed payload
 by C. Masloch, 2018

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.


Includes the BriefLZ depacker, which is under separate usage conditions.
(Refer to brieflz.asm for the BriefLZ usage conditions.)

%endif

%include "lmacros2.mac"

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

	numdef BRIEFLZ,		0
	numdef LZ4,		0
	numdef SNAPPY,		0
	numdef EXODECR,		0
%if (!!_BRIEFLZ + !!_LZ4 + !!_SNAPPY + !!_EXODECR) != 1
 %error Exactly one compression method must be selected.
%endif
%if _BRIEFLZ
	strdef PAYLOAD_FILE,	"lDOSLOAD.BLZ"
%elif _LZ4
	strdef PAYLOAD_FILE,	"lDOSLOAD.LZ4"
%elif _SNAPPY
	strdef PAYLOAD_FILE,	"lDOSLOAD.SZ"
%elif _EXODECR
	strdef PAYLOAD_FILE,	"lDOSLOAD.EXO"
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

%if _IMAGE_EXE
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
	mov bx, 0		; kernel mode
	push ax
	mov ax, cs
	add ax, (init0_end - init0_start) >> 4
	mov dx, word [ bp + ldLoadTop ]	; => after end of available space
	mov si, 60h		; => destination
	jmp init0_common

	align 64, nop
init0_exe_entry:
		; NOTE:	This part is called with ip = 256 + 64, cs = PSP.
%if ($ - $$) != 64
 %error Wrong EXE mode entrypoint
%endif
	mov bx, 1		; EXE mode
	push ax
	mov dx, ss		; => after end of available space
	mov ax, cs
	add ax, (256 + (init0_end - init0_start)) >> 4	; => source
	mov si, cs
	add si, 256 >> 4	; => destination

init0_common:
		; NOTE:	This part must be position-independent, as it is
		;	 called either with ip = init0_common (kernel mode)
		;	 or ip = init0_common + 256 (EXE mode).
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
	sub dx, cx
%endif
	push si
	call init0_movp
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

	mov ax, dx
%if _TEST_PROGRAM
	add ax, ( \
		+ (payload_end - payload) \
		+ (init1_end - init1_start) \
		) >> 4
%else
	add ax, ( \
		+ (payload_end - payload) \
		) >> 4
%endif
	xor cx, cx
	push ax
	push cx
	retf			; jump to relocated INIT1:init1_start


%if _TEST_PROGRAM
.error:
	push cs
	pop ds
	mov dx, init0_msg.error_stderr + 256
	mov cx, init0_msg.error_stderr.length
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
		;	if not _IMAGE_EXE, or if kernel mode:
		;	 ss:bp -> LOADDATA and LOADSTACKVARS
		;	 ss:sp -> valid stack above [bp + ldLoadTop]
		;	 60h => destination
		;	if _IMAGE_EXE, either mode:
		;	 word [ss:sp] = value for ax
		;	 bx = 1 if EXE mode, 0 if kernel mode
		;	 si => destination (60h for kernel mode,
		;				after PSP for EXE mode)
		;	 if EXE mode:
		;	  ss:sp -> valid stack above INIT1
		;	  bp = unset
		; CHG:	ax, bx, cx, dx, es, ds, si, di
%if _IMAGE_EXE
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

	cld

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
		;	ax = maximum amount in paragraphs of destination needed
		;	 (-1 if unused, meaning entire destination needed)
		; Note:	The destination reaches up to below the source.
	call depack
%ifn _TEST_PROGRAM
	jc strict short error
%endif
%if _IMAGE_EXE
	pop si			; si
	pop bx			; ?exemode
	pop bp			; bp
	pop ax			; ax
	lleave ctx
%endif
%if _TEST_PROGRAM
	retf
	nop
%endif

%if _IMAGE_EXE
	test bx, 1
	jz .jmp_kernel_mode

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

	mov cx, _IMAGE_EXE_IP
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

.jmp_kernel_mode:
%endif
	jmp 60h + _EXEC_SEGMENT:_EXEC_OFFSET


error:
	push cs
	pop ds
%if _DEBUG0
	mov si, msg.error_begin
	call disp_error
	mov ax, bx
	call disp_ax_hex
	mov si, msg.error_end
%else
	mov si, msg.error
%endif
	call disp_error

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

disp_error:
.:
	lodsb
	test al, al
	jz .ret
	call disp_al
	jmp short .

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
%if _IMAGE_EXE
	push dx

	test byte [bp - 2], 1
	jz .display_kernel_mode

	mov dl, al
	mov ah, 02h
	int 21h
	jmp .common

.display_kernel_mode:
%endif
	mov ah, 0Eh
	mov bx, 7
	int 10h
%if _IMAGE_EXE
.common:
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


%if _ALLOW_OVERLAPPING
		; INP:	?src, ?dst
		; OUT:	CY if error (?src < ?dst)
		;	NC if success
		; CHG:	ax, bx, cx, dx
check_pointers_not_overlapping:
	 push word [bp + ?dst + 2]
	 push word [bp + ?dst]
	call pointer_to_linear

	xchg cx, ax
	xchg bx, dx			; bx:cx = linear ?dst after write

	 push word [bp + ?src + 2]
	 push word [bp + ?src]
	call pointer_to_linear		; dx:ax = linear ?src before next read

	cmp dx, bx			; ?src >= ?dst ?
	ja @F
	jb .ret				; (CY)
	cmp ax, cx
	; jb .ret			; (CY)
					; (NC) yes, no error
@@:
.ret:
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
	 push ds
	 push si
	call normalise_pointer
	 pop si
	 pop ds

	 push es
	 push di
	call normalise_pointer
	 pop di
	 pop es
	retn


		; INP:	word [ss:sp + 2] = segment
		;	word [ss:sp] = offset
		;
		; Note:	Does not work correctly with pointers that point to
		;	 a HMA location. Do not use then!
normalise_pointer:
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
normalise_pointer_with_displacement_bxcx:
	lframe near
	lpar word,	segment
	lpar word,	offset
	lpar_return
	lenter
	push ax
	push dx

	 push word [bp + ?segment]
	 push word [bp + ?offset]
	call pointer_to_linear

	; push bx
	; 				; sign-extend cx into bx:cx
	; cmp cx, 8000h			; CY if < 8000h (NC if negative)
	; cmc				; NC if positive
	; sbb bx, bx			; 0 if was NC, -1 if was CY

	add ax, cx
	adc dx, bx			; dx:ax += bx:cx
	; pop bx

%if 0
		; Adds in HMA support for this function. Not currently used.
	cmp dx, 10h			; dx:ax >= 10_0000h ?
	jb @F				; no, linear-to-pointer normally -->
	; ja .error

	add ax, 10h
	; jc .error
	mov word [bp + ?offset], ax
	or word [bp + ?segment], -1
	jmp .return
@@:
%endif

	push ax
	and ax, 15
	mov word [bp + ?offset], ax
	pop ax

%rep 4
	shr dx, 1
	rcr ax, 1
%endrep
	mov word [bp + ?segment], ax

	; test dx, dx
	; jnz .error

.return:
	pop dx
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
%rep 4
	shl ax, 1
	rcl dx, 1
%endrep

	add ax, word [bp + ?offset]
	adc dx, 0

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

	mov dx, ax		; => payload source to use
	mov ax, cs
	sub ax, (init1_end - init1_start) >> 4
				; => INIT1
	mov bx, 1		; say we're in EXE mode
	push dx
	push ax
	push si
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
	lframe
	lenter
	lvar word,	upperbound
	 push dx
	lvar word,	lowerbound
	 push si
	lvar word,	current_init1
	 push ax

.loop:
	mov dx, [bp + ?upperbound]
	sub dx, [bp + ?lowerbound]
	jz .found
	shr dx, 1
		; Rounding down, so that we never retry upper bound.
		;  The upper bound is known to be working.
	add dx, [bp + ?lowerbound]
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
		; error: this attempt is one below the new lower bound
	inc dx
	mov word [bp + ?lowerbound], dx
	jmp .loop

@@:
		; success: this attempt is the new upper bound
	mov word [bp + ?upperbound], dx
	jmp .loop

.found:
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

	lleave ctx


.transfer:
	xor di, di
	push di			; dummy ax value on stack
	push ax			; INIT1 segment
	push di			; zero = init1_start
	retf

init2_error:
	push cs
	pop ds
	mov bx, 2
	mov ah, 40h
	int 21h
	mov dx, init2_msg.error_stdout
	mov cx, init2_msg.error_stdout.length
	mov bx, 1
	mov ah, 40h
	int 21h
	mov ax, 4CFFh
	int 21h


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
.initial_error:	db "Error: Test program failed to decompress with full buffer.",13,10
.initial_error.length: equ $ - .initial_error
.error_stdout:	_autodigits paras(_TEST_PROGRAM_DECOMPRESSED_SIZE \
				+ (payload_end - payload) \
				+ (init1_end - init1_start) \
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

	numdef INCLUDE_UNCOMPRESSED
	strdef UNCOMPRESSED_FILE, "lDOSLOAD.BIN"
%if _INCLUDE_UNCOMPRESSED
payload_uncompressed:
	incbin _UNCOMPRESSED_FILE
	db 38
	align 16, db 38
%endif
init2_end:
%endif

