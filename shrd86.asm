;This is depacker for data compressed with Shrinkler by Aske Simon Christensen.
;You can freely use it as you like.
;Uses only 8086 instructions, suitable for IBM PC/XT (~2 KB/s on 4.77 MHz 8088).
;Assembled size is 177 bytes.

%assign NEED_NORMALISE_POINTER_WITH_DISPLACEMENT 1
%assign NEED_NORMALISE_BOTH_POINTERS 1
%assign CHECK_POINTERS_VARIABLE_SRC 0
%assign CHECK_POINTERS_VARIABLE_DST 0

NUM_CONTEXTS equ 1024
INIT_ONE_PROB equ 0x8000
ADJUST_SHIFT equ 4

localvariables_size equ fromparas(paras(NUM_CONTEXTS*2))

		; INP:	ds:si -> source
		;	dx:cx = length of source
		;	es:di -> destination (below source)
		;	if _IMAGE_EXE:
		;	 bx = EXE mode flag (bit 0)
		;	else:
		;	 bx = 0
		;	if _PAYLOAD_KERNEL_MAX_PARAS:
		;	 ax = maximum amount in paragraphs of destination needed
		;	 (-1 if full source should be decompressed)
		;	else:
		;	 ax = -1
		; OUT:	NC if success
		;	CY if error,
		;	 bx = ?errordata (if _DEBUG0)
		; CHG:	ax, (bx), cx, dx, es, ds, si, di
		; STT:	UP
		;
		; Note:	The destination reaches up to below the source.
		; Note:	The input pointers need not be normalised yet.
		;	 Normalised means that the offset part is below 16.
depack:
	lframe near
%if _SCAN
	lpar word, buffer
	lpar word, bufferparas
	lpar dword, bufferbytes
	lpar dword, progressticks
	lpar dword, maxbytesahead
	lpar dword, depackedsize
	lpar_return
%endif

%if _IMAGE_EXE || _DEBUG0 || _COUNTER
	lenter early
 %if _IMAGE_EXE
	lvar word,	exemode	; must be bp - 2!
	 push bx
  %if ?exemode != -2
   %error exemode variable must be directly below bp
  %endif
 %endif
 %if _DEBUG0 || _COUNTER
	xor bx, bx
 %endif
 %if _DEBUG0
	lvar word,	errordata
	 push bx
 %endif
%endif
	lvar word,	counter
%if _COUNTER
	 push bx		; initialise counter (high byte) to zero
%endif
	lvar word,	matchlength

%if _SCAN
	lvar dword,	plusdst
	lvar dword,	plussrc
%endif
	lvar word,	lastbyte; high byte is clobbered by a pop
	lenter

%if _SCAN
	mov es, word [bp + ?buffer]
	xor di, di		; destination

	cmp word [bp + ?bufferparas], paras(localvariables_size)
	jb .error
%endif
	call normalise_both_pointers

%if _SCAN
	lvar dword,	original_src
	 push ds
	 push si
%endif
	lvar dword,	src
	 push ds
	 push si
	lvar dword,	final_dst
	lequ ?final_dst,localvariables
	 push es
	 push di

	lvar dword,	length_of_source
	 push dx
	 push cx

%if 0 ; && _PAYLOAD_KERNEL_MAX_PARAS
	cmp ax, -1		; no maximum specified ?
	je @FF			; retain -1 in ax -->
	test di, di		; do we need an additional paragraph ?
	jz @F			; no -->
	inc ax			; es + ax => paragraph after necessary part
@@:
	mov dx, es
	add ax, dx		; => paragraph after necessary part
		; If the normalised destination pointer's segment grows
		;  to this segment then enough has been decompressed.
d0	mov byte [bp + ?errordata], 40h
	jc .error		; should not carry
@@:
	lvar word,	dst_max_segment
	 push ax
%endif

%if _SCAN
LENDST equ 960 * 1024
	mov bx, LENDST >> 16
	mov cx, LENDST & 0FFFFh
%else
	 push ds
	 push si
	call pointer_to_linear

	mov bx, dx
	xchg cx, ax		; bx:cx = source linear

	 push es
	 push di
	call pointer_to_linear

%if _ALLOW_OVERLAPPING
	add cx, word [bp + ?length_of_source]
	adc bx, word [bp + ?length_of_source + 2]
		; In case of allowing overlapping source and destination,
		;  the ?length_of_destination variable is set to
		;  ?src + ?length_of_source - ?dst, allowing to write to
		;  all of the source buffer (with the checks already in place
		;  from the default handling). Additional checks are done by
		;  calling check_pointers_not_overlapping. This is done after
		;  every change of ?dst to verify that the write pointer stays
		;  below-or-equal the read pointer.
		; This means the remaining source data may be corrupted by a
		;  write, but nothing after the source data is written to,
		;  so the error handling (in INIT1 after the data) still works.
%endif

	sub cx, ax
	sbb bx, dx		; bx:cx = source linear - destination linear
%endif	; _SCAN

	sub cx, localvariables_size & 0FFFFh
	sbb bx, localvariables_size >> 16
	jb .error		; make variables buffer available

%if _SCAN
	xor di, di
	mov es, di		; destination = all-zeroes (special)
%else
	mov ax, es
	add ax, paras(localvariables_size)
	mov es, ax
%endif

	lvar dword,	original_dst
	 push es
	 push di
	lvar dword,	dst
	 push es
	 push di

	lvar dword,	length_of_destination
	 push bx		; push into [bp + ?length_of_destination + 2]
	 push cx		; push into [bp + ?length_of_destination]

%if _ALLOW_OVERLAPPING
	call check_pointers_not_overlapping
		; Note:	We initially check here that the write pointer is
		;	 low enough, ie below-or-equal the read pointer.
		;	 Doing this check here (as well as after any
		;	 copied match) allows us to drop the check done
		;	 after moving literal bytes.
d0	mov byte [bp + ?errordata], 1Bh
	jc .error
%endif

	les di, [bp + ?localvariables]
mov cx, NUM_CONTEXTS
mov ax, INIT_ONE_PROB
.init_prob:
	stosw
loop .init_prob


	les di, [bp + ?dst]
	lvar word, base
	 push cx
	lvar word, context_di
	 push cx
	lvar dword, offset
	 push ax
	 push ax		; must be last word on stack

	add word [bp + ?length_of_source], 2
	adc word [bp + ?length_of_source + 2], 0
				; apparently the End Of Data marker may read
				;  up to 2 more bytes from the source than are
				;  present in the compressed source data.
				; allow reading these here (see also .end_check).

;range decoder state
inc cx
	; ?base=0 - base
;cx=1 - range

%if 0
	inc si			; -> behind first byte
%else
	; call normalise_dssi_pointer
	stc	; CY, cf=1
	lodsb
	mov byte [bp + ?lastbyte], al
	rcl byte [bp + ?lastbyte], 1
	rcl word [bp + ?base], 1
add cx, cx
%endif

xor bx, bx
.lit:
;bl=0 after getkind
inc bx
.getlit:
call getbit
adc bl, bl
jnc .getlit
xchg ax, bx
	sub word [bp + ?length_of_destination], 1
	sbb word [bp + ?length_of_destination + 2], 0
	jc depack.error
	add word [bp + ?context_di], 1
stosb
	cmp di, 0FFE0h
	jb @F
	 push es
	 push di
	call normalise_pointer
	 pop di
	 pop es
@@:

call getkind
jnc .lit
mov bh, 2
call getbit
jnc .readoff
.readlen:
mov bh, 2
call getnum
	test ax, ax
	jne .error
pop bx		; ?offset value can be reused later, must be saved
	pop ax
	push ax
push bx

	push cx
	push ds
	push si
	sub word [bp + ?length_of_destination], dx
	sbb word [bp + ?length_of_destination + 2], 0
	jc depack.error
	add word [bp + ?context_di], dx

	mov cx, bx
	xchg bx, ax
	 push es
	 push di
	call normalise_pointer_with_displacement_bxcx
	 pop si
	 pop ds

%if 1
	mov ax, di
	add ax, 20h
	jc .normalise
	add ax, dx
	jnc @F
.normalise:
%endif
	 push es
	 push di
	call normalise_pointer
	 pop di
	 pop es
@@:

	mov cx, dx
	cmp cx, 0FFE0h
	jbe @F
	push cx
	mov cx, 0FFE0h
	rep movsb
	pop cx
	and cx, (~ 0FFE0h) & 0FFFFh
	call normalise_both_pointers
@@:
	rep movsb

	pop si
	pop ds
%if _ALLOW_OVERLAPPING
	push bx
	call check_pointers_not_overlapping
	pop bx
	jc depack.error
%endif
	xor dx, dx
	pop cx

call getkind
jnc .lit
.readoff:
mov bh, 3
call getnum
	add sp, 4	; discard 2 words
	neg ax
	neg dx
	sbb ax, 0	; neg ax:dx
	add dx, 2
	adc ax, 0	; offset=2-getnum()
	push ax
	push dx		; save ?offset value
@@:
	jnz .readlen
	test dx, dx
	jnz @B

.end_check:
	cmp word [bp + ?length_of_source + 2], 0
	ja @F
	cmp word [bp + ?length_of_source], 2
@@:				; 0, 1, or 2 bytes allowed to be left, due to
	ja .error		;  the possible reading past last source data

; Original depacker's comment, note the "two next bytes" notice:
;How to use:
;ds:si - must point to byte 0x80 immediately followed by compressed data block.
;es:di - decompressed data pointer, value in di must be even!
;Call shrd86, after decompressing it will return decompressed data size in ax.
;Also it will rewrite compressed data block with zeroes and can change up to two next bytes.
;It uses 2 KB on the stack.

.end:

	 push es
	 push di
	les di, [bp + ?final_dst]
				; -> destination
	lds si, [bp + ?original_dst]
				; -> source
	 push ds
	 push si
	call pointer_to_linear	; dx:ax = linear ?original_dst
	xchg cx, ax
	xchg bx, dx		; bx:cx = linear ?original_dst, clobber dx:ax
	 ; push word [bp + ?dst + 2]
	 ; push word [bp + ?dst]
	call pointer_to_linear
	sub ax, cx
	sbb dx, bx		; = linear dst minus linear original_dst
%if _SCAN
	mov word [bp + ?depackedsize], ax
	mov word [bp + ?depackedsize + 2], dx
	add word [bp + ?maxbytesahead], localvariables_size & 0FFFFh
	adc word [bp + ?maxbytesahead + 2], localvariables_size >> 16
%endif

	mov cx, 4
	add ax, 15
	adc dx, 0
@@:
	shr dx, 1
	rcr ax, 1
	loop @B
	mov cx, ax
	test dx, dx
d0	mov byte [bp + ?errordata], 84h
	jnz .error

%ifn _SCAN
	call x_mov_p
%endif

	db __TEST_IMM8			; (NC)
.error:
	stc

%if _COUNTER
	lahf
	mov al, 13
	call disp_al_for_progress
	mov al, 10
	call disp_al_for_progress
	sahf
%endif
d0	mov bx, word [bp + ?errordata]
	lleave code
	lret


readbit:
	shl byte [bp + ?lastbyte], 1
jnz .nonewbyte
	sub word [bp + ?length_of_source], 1
	sbb word [bp + ?length_of_source + 2], 0
	jc depack.error
	call normalise_dssi_pointer
	push word [si]
	pop word [bp + ?lastbyte]
	stc	; CY, cf=1
	rcl byte [bp + ?lastbyte], 1
	inc si
.nonewbyte:
	rcl word [bp + ?base], 1
add cx, cx

getbit:
test cx, cx
jns readbit
push bx
add bx, bx
prob_base:
	add bx, word [bp + ?localvariables]
	push ds
	mov ds, word [bp + ?localvariables + 2]
	mov ax, [bx]
push cx
mov cl, ADJUST_SHIFT
shr ax, cl
pop cx
	sub [bx], ax
	add ax, [bx]
mul cx
	sub word [bp + ?base], dx
jc .one
sub cx, dx
	pop ds
pop bx
ret
.one:
	add word [bx], 0xFFFF>>ADJUST_SHIFT
mov cx, dx
	add word [bp + ?base], dx
	pop ds
pop bx
ret

getkind:
mov bx, 1
%if 0
and bx, di ;di value is used as context
           ;and Shrinkler assumes it's even for the first byte
%else
	and bx, word [bp + ?context_di]
%endif
xchg bh, bl
call getbit
ret

getnum:
.numloop:
inc bx
call getbit
jc .numloop
neg bl
	xor ax, ax
mov dx, 1
.bitloop:
push ax
push dx
call getbit
pop dx
pop ax
	adc dx, dx
	adc ax, ax
inc bl
jnz .bitloop
ret

%ifn _SCAN
		; Move paragraphs
		;
		; INP:	ds:si -> source
		;	es:di -> destination
		;	cx = number of paragraphs
		; CHG:	ax, bx, cx, dx
		; OUT:	ds:si -> after source (normalised)
		;	es:di -> after destination (normalised)
		; Note:	Doesn't work correctly on HMA; doesn't always wrap to LMA either.
		;	Do not provide a wrapped/HMA source or destination!
x_mov_p:
	call normalise_both_pointers
	mov ax, ds
	mov dx, es

	test cx, cx
	jz .return

%if 0
	cmp ax, dx		; source above destination ?
	ja .up			; yes, move up (forwards) -->
	jb .check_down

	cmp si, di
	ja .up
	je .return		; pointers are the same, no need to move -->
.check_down:
	push ax
	add ax, cx		; (expected not to carry)
	cmp ax, dx		; end of source is above destination ?
	pop ax
	ja .down		; yes, move from top down -->
	jb .up
	cmp si, di
	ja .down
%endif

	; Here, the end of source is below-or-equal the destination,
	;  so they do not overlap. In this case we prefer moving up.
.up:
.uploop:
	sub cx, 0FFFh		; 64 KiB - 16 B left ?
	jbe .uplast		; no -->
	push cx
	mov cx, 0FFF0h /2
	rep movsw		; move 64 KiB - 16 B
	pop cx
	call normalise_both_pointers
	jmp short .uploop	; proceed for more -->
.uplast:
	add cx, 0FFFh		; restore counter
	shl cx, 1
	shl cx, 1
	shl cx, 1		; *8, paragraphs to words
	rep movsw		; move last part
%if 0
	jmp short .return

.down:
	std			; _AMD_ERRATUM_109_WORKAROUND as below

	mov ax, cx
	xor bx, bx
	push cx
	mov cx, 4
@@:
	shl ax, 1
	rcl bx, 1
	loop @B
	sub ax, 2
	sbb bx, 0		; -> point at last word
		; (Cannot borrow here because we checked that cx
		;  was nonzero at the intro to this function, so
		;  bx:ax is at least 16 prior to this subtraction.)
	xchg ax, cx		; bx:cx = displacement to point to last word
	 push ds
	 push si
	call anti_normalise_pointer_with_displacement_bxcx
	 pop si
	 pop ds			; -> last word of source
	 push es
	 push di
	call anti_normalise_pointer_with_displacement_bxcx
	 pop di
	 pop es			; -> last word of destination
	pop cx

.dnloop:
	sub cx, 0FFFh		; 64 KiB - 16 B left ?
	jbe .dnlast		; no -->
	push cx
	mov cx, 0FFF0h /2
	rep movsw		; move 64 KiB - 16 B
	pop cx
	call anti_normalise_both_pointers
	jmp short .dnloop	; proceed for more -->
.dnlast:
	add cx, 0FFFh		; restore counter
	shl cx, 1
	shl cx, 1
	shl cx, 1		; *8, paragraphs to words


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
%endif

.return:
	jmp normalise_both_pointers
%endif
