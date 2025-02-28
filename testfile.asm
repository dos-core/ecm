
%if 0

lDOS depacker test
 by E. C. Masloch, 2018--2024

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.


Includes one of several depackers, some of which are under
separate usage conditions. Refer to the individual depacker
source files for the applicable usage conditions.

%endif

%include "lmacros3.mac"


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

	numdef OPTIMISE_INPUT_SMALL,	0
	numdef OPTIMISE_OUYPUT_SMALL,	0
	numdef ALLOW_OVERLAPPING,	1	; allow overlapping src and dst

	numdef IMAGE_EXE,	1
	numdef DEVICE,		0
	numdef BOOTLDR,		0

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
%if (!!_BRIEFLZ + !!_LZ4 + !!_SNAPPY + !!_EXODECR + !!_X + !!_HEATSHRINK \
	+ !!_LZD + !!_LZO + !!_LZSA2 + !!_APL + !!_BZP + !!_ZEROCOMP \
	+ !!_MVCOMP) != 1
 %fatal Exactly one compression method must be selected.
%endif
%assign ADDITIONAL_MEMORY 0
	numdef PAYLOAD_KERNEL_MAX_PARAS,	0, 0
	numdef PROGRESS,	0, 1
	numdef COUNTER,		0, 32
%if (_COUNTER - 1) & _COUNTER
 %error COUNTER must be a power of two
%endif


	cpu 8086
	org 256
	addsection DEPACKER
start:
	cmp sp, stack_top
	jae @F
.oom:
	mov dx, msg.oom
	mov ah, 09h
	int 21h
	mov ax, 4C01h
	int 21h

@@:
	mov sp, stack_top
	mov bx, paras(256 + stack_top - start)
	mov ah, 4Ah
	int 21h
	xor ax, ax
	xchg ax, word [2Ch]
	test ax, ax
	jz @F
	mov es, ax
	mov ah, 49h
	int 21h
@@:
	mov bx, -1
	mov ah, 48h
	int 21h
	mov ah, 48h
	int 21h
	jc .oom
	mov word [allocparas], bx
	mov word [allocseg], ax

	push ss
	pop es
	mov si, 81h
cmdloop:
	lodsb
.al:
	cmp al, 9
	je cmdloop
	cmp al, 32
	je cmdloop
	cmp al, 13
	jbe cmdend
	cmp al, [switch]
	jne .filename
	lodsb
	call cap
	cmp al, '-'
	jne @F
	mov byte [switch], 0
	jmp cmdloop

@@:
	cmp al, 'V'
	jne @F
	mov byte [verbose], 0FFh
	jmp cmdloop

@@:
	cmp al, 'E'
	jne @F
	mov byte [exceptional], 0FFh
	jmp cmdloop

@@:
	cmp al, 'B'
	jne @F
	mov byte [..@breakpoint], 0CCh
	jmp cmdloop

@@:
.invalidswitch:
	mov byte [msg.invalidswitch.letter], al
	mov dx, msg.invalidswitch
	call disp_msg_counted
	mov ax, 4C02h
	int 21h

.filename:
	mov bx, [nextfile]
	cmp bx, nomorefile
	jb @F
	mov dx, msg.toomanyfiles
	call disp_msg_counted
	mov ax, 4C03h
	int 21h

@@:
	add word [nextfile], 2
	dec si
	mov di, si
	mov word [bx], si
	mov ah, 0
.fileloop:
	lodsb
	cmp al, '"'
	jne @F
	not ah
	jmp .fileloop

@@:
	cmp ax, 32
	je .fileend
	cmp ax, 9
	je .fileend
	cmp ax, 0FF00h + 13
	jne @F
	mov dx, msg.quotedeol
	call disp_msg_counted
	mov ax, 4C04h
	int 21h

@@:
	cmp al, 13
	jbe .fileend

	stosb
	jmp .fileloop

.fileend:
	push ax
	mov al, 0
	stosb
	pop ax
	jmp cmdloop.al

cmdend:

openinfile:
	mov si, word [infile]
	test si, si
	jnz @F
	mov dx, msg.noinfile
	call disp_msg_counted
	mov ax, 4C05h
	int 21h

@@:
	mov ax, 716Ch
	xor cx, cx
	xor di, di
	mov dx, 1		; open existing file
	mov bx, 0_01_00_000_1_010_0_000b
				; no int 24h, no inherit, deny write, read-only
	stc
	int 21h
	jnc gotinfile
	cmp ax, 7100h
	je @F
	cmp ax, 1
	jne .error
@@:
	mov ax, 6C00h
	stc
	int 21h
	jnc gotinfile
	cmp ax, 6C00h
	je @F
	cmp ax, 1
	jne .error
@@:
	xchg ax, bx
	mov ah, 3Dh
	int 21h
	jnc gotinfile
.error:
	 push ss
	 pop ds
	 push ss
	 pop es
	mov di, msg.infileerror.code
	call store_hex_word
	mov dx, msg.infileerror
	call disp_msg_counted
	mov ax, 4C05h
	int 21h

gotinfile:
	mov word [inhandle], ax
	xchg bx, ax
	mov ax, 4202h
	xor cx, cx
	xor dx, dx
	int 21h
	jc openinfile.error

	mov word [insize], ax
	mov word [insize + 2], dx
	mov word [toread], ax
	mov word [toread + 2], dx

	mov si, 0FFFFh
	add ax, 15
	adc dx, 0
	jc .toolarge
	mov cx, 4
@@:
	shr dx, 1
	rcr ax, 1
	loop @B
	test dx, dx
	jnz .toolarge
	mov si, ax
	cmp ax, word [allocparas]
	jb @F
.toolarge:
	mov di, msg.infiletoolarge.available
	mov ax, [allocparas]
	call store_hex_word
	mov di, msg.infiletoolarge.needed
	xchg ax, si
	call store_hex_word
	mov dx, msg.infiletoolarge
	call disp_msg_counted
	mov ax, 4C06h
	int 21h

@@:
	mov ax, 4200h
	xor cx, cx
	xor dx, dx
	int 21h
	jc openinfile.error


read:
	mov dx, word [allocseg]
	add dx, word [allocparas]
	sub dx, si
	mov word [source + 2], dx
	mov ds, dx
	xor dx, dx

.loop:
	cmp word [ss:toread + 2], 0
	jne @F
	cmp word [ss:toread], 56 * 1024
@@:
	jb .last
	mov cx, 56 * 1024
	mov ah, 3Fh
	int 21h
	jc openinfile.error
	cmp ax, cx
	jne .short
	sub word [ss:toread], ax
	sbb word [ss:toread + 2], 0
	mov cx, ds
	add cx, paras(56 * 1024)
	mov ds, cx
	jmp .loop

.short:
	 push ss
	 pop ds
	mov dx, msg.infileshort
	call disp_msg_counted
	mov ax, 4C07h
	int 21h

.last:
	mov cx, word [ss:toread]
	mov ah, 3Fh
	int 21h
	jc openinfile.error
	cmp ax, cx
	jne .short
	 push ss
	 pop ds


openoutfile:
	mov si, word [outfile]
	test si, si
	jnz @F
	mov dx, msg.nooutfile
	call disp_msg_counted
	mov ax, 4C05h
	int 21h

@@:
	mov ax, 716Ch
	xor cx, cx
	xor di, di
	mov dx, 12h		; create or truncate file
	mov bx, 0_01_00_000_1_010_0_001b
				; no int 24h, no inherit, deny write, write-only
	stc
	int 21h
	jnc gotoutfile
	cmp ax, 7100h
	je @F
	cmp ax, 1
	jne .error
@@:
	mov ax, 6C00h
	stc
	int 21h
	jnc gotoutfile
	cmp ax, 6C00h
	je @F
	cmp ax, 1
	jne .error
@@:
	xchg ax, bx
	mov ah, 3Ch
	int 21h
	jnc gotoutfile
.error:
	 push ss
	 pop ds
	 push ss
	 pop es
	mov di, msg.outfileerror.code
	call store_hex_word
	mov dx, msg.outfileerror
	call disp_msg_counted
	mov ax, 4C08h
	int 21h

gotoutfile:
	mov word [outhandle], ax

run:
	mov bx, 1		; tell exe mode

	lframe
	lenter
	lvar word,	exemode		; must be bp - 2!
	 push bx
 %if ?exemode != -2
  %error exemode variable must be directly below bp
 %endif

	mov cx, [insize]
	mov dx, [insize + 2]	; = length of source
	les di, [dest]		; -> destination
	lds si, [source]	; -> source

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
		; OUT:	NC if success,
		;	 es:di -> past destination
		;	CY if error,
		;	 bx = ?errordata (if _DEBUG0)
		; CHG:	ax, (bx), cx, dx, (es), ds, si, (di)
		; STT:	UP
		; Note:	The destination reaches up to below the source.
..@breakpoint:
	nop

	call depack
	jc error
%if _IMAGE_EXE || _DEVICE
	pop bx			; ?exemode
	pop bp			; bp
	lleave ctx
%endif

	push ss
	pop ds

	push word [dest + 2]
	push word [dest]
	call pointer_to_linear

	xchg cx, ax
	xchg bx, dx

	push es
	push di
	call pointer_to_linear

	sub ax, cx
	sbb dx, bx
	mov bx, -1
	jc error

	push ss
	pop es

write:
	mov word [outsize], ax
	mov word [outsize + 2], dx
	mov word [towrite], ax
	mov word [towrite + 2], dx

	mov bx, word [outhandle]
	lds dx, [dest]
.loop:
	cmp word [ss:towrite + 2], 0
	jne @F
	cmp word [ss:towrite], 56 * 1024
@@:
	jb .last
	mov cx, 56 * 1024
	mov ah, 40h
	int 21h
	jc openoutfile.error
	cmp ax, cx
	jne .short
	sub word [ss:towrite], ax
	sbb word [ss:towrite + 2], 0
	mov cx, ds
	add cx, paras(56 * 1024)
	mov ds, cx
	jmp .loop

.short:
	 push ss
	 pop ds
	mov dx, msg.outfileshort
	call disp_msg_counted
	mov ax, 4C09h
	int 21h

.last:
	mov cx, word [ss:towrite]
	mov ah, 40h
	int 21h
	jc openoutfile.error
	cmp ax, cx
	jne .short
	 push ss
	 pop ds

	mov dx, msg.done
	call disp_msg_counted
	mov ax, 4C00h
	int 21h


disp_al_counter equ disp_al

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

	mov ax, 4C7Fh
	int 21h


cap:
	cmp al, 'a'
	jb .ret
	cmp al, 'z'
	ja .ret
	xor al, 20h
.ret:
	retn


disp_msg_counted:
	push ax
	push bx
	push cx
	push dx
	xor cx, cx
	mov bx, dx
	inc dx
	mov cl, [bx]
	mov bx, 1
	mov ah, 40h
	int 21h
	pop dx
	pop cx
	pop bx
	pop ax
	retn


store_hex_word:
	xchg al, ah
	call store_hex_byte
	xchg al, ah

store_hex_byte:
	push cx
	mov cl, 4
	rol al, cl
	call store_hex_nybble
	rol al, cl
	pop cx

store_hex_nybble:
	push ax
	and al, 15
	add al, '0'
	cmp al, '9'
	jbe @F
	add al, - ('9' + 1) + 'A'
@@:
	stosb
	pop ax
	retn


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
disp_al:
	push ax
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
.done:		counted "Done.",13,10
.oom:		ascic "Error: Out of memory!",13,10
.invalidswitch:	db @F - ($ + 1)
		db "Error: Invalid switch ",'"'
.invalidswitch.letter:
		db 'x"!',13,10
@@:
.toomanyfiles:	counted "Error: Too many files specified!",13,10
.quotedeol:	counted "Error: Missing closing quote mark!",13,10
.noinfile:	counted "Error: No input file specified!",13,10
.nooutfile:	counted "Error: No output file specified!",13,10
.infileerror:	db @F - ($ + 1)
		db "Error: Input file open, seek, or read error "
.infileerror.code:
		db "----h!",13,10
@@:
.outfileerror:	db @F - ($ + 1)
		db "Error: Output file open or write error "
.outfileerror.code:
		db "----h!",13,10
@@:
.infiletoolarge:db @F - ($ + 1)
		db "Error: Input file is too large, need="
.infiletoolarge.available:
		db "----h paragraphs, have="
.infiletoolarge.needed:
		db "----h paragraphs!",13,10
@@:
.:		db @F - ($ + 1)
@@:
.infileshort:	counted "Error: Short read from input file!",13,10
.outfileshort:	counted "Error: Short write to output file! (Disk full?)",13,10

%if _DEBUG0
.error_begin:	db "Load error: Decompression failure, code ",0
.error_end:	db "h.",13,10,0
%else
.error:		db "Load error: Decompression failure.",13,10,0
%endif


%assign NEED_NORMALISE_POINTER_WITH_DISPLACEMENT 1
%assign CHECK_POINTERS_VARIABLE_SRC 1
%assign CHECK_POINTERS_VARIABLE_DST 1

%assign _TESTFILE_SUPPORTED 0
%assign _TESTFILE 1

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


%ifn _TESTFILE_SUPPORTED
 %error This compression method does not support test file mode yet.
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


	align 4
dest:		dw 0			; must be directly before allocseg
allocseg:	dw 0
source:		dd 0
nextfile:	dw infile
infile:		dw 0
outfile:	dw 0
nomorefile:
switch:		db '-'
verbose:	db 0
exceptional:	db 0


	absolute $
	alignb 4
insize:		resd 1
outsize:	resd 1
towrite:
toread:		resd 1
inhandle:	resw 1
outhandle:	resw 1
allocparas:	resw 1
	alignb 16
end:
		resb 512
	alignb 16
stack_top:
