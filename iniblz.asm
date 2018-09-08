
%if 0

lDOS iniload packed payload
 by C. Masloch, 2018

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.


Contains BriefLZ depacker, which is under separate usage conditions.

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

	strdef PAYLOAD_FILE,	"lDOSLOAD.BLZ"
	numdef EXEC_OFFSET,	0
	numdef EXEC_SEGMENT,	0
	numdef IMAGE_EXE,	0
%if _IMAGE_EXE
 %error iniload _IMAGE_EXE option is not supported yet.
%endif


	cpu 8086
	section INIT0 start=0 vstart=0
init0_start:
	cld
	mov ax, cs
	add ax, (init0_end - init0_start) >> 4
	mov cx, ( (payload_end - payload) \
		+ (init1_end - init1_start) \
		) >> 4
	mov dx, word [ bp + ldLoadTop ]
	sub dx, cx
	call init0_movp

	mov ax, dx
	add ax, ( \
		+ (payload_end - payload) \
		) >> 4
	xor bx, bx
	push ax
	push bx
	retf


		; Move paragraphs
		;
		; INP:	ax:0-> source
		;	dx:0-> destination
		;	cx = number of paragraphs
		; CHG:	-
		; OUT:	NC
		; Note:	Doesn't work correctly on HMA; doesn't always wrap to LMA either.
		;	Do not provide a wrapped/HMA source or destination!
init0_movp:
	push cx
	push ds
	push si
	push es
	push di

	cmp ax, dx		; source below destination ?
	jb .down		; yes, move from top down -->
	je .return		; same, no need to move --> (NC)

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
	shl cx, 1		; *8, paragraphs to words (NC)
	rep movsw		; move last part
	pop dx
	pop ax
	jmp short .return

.down:
	std
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
	shl di, 1		; words to offset, -> last word (NC)
	mov si, di
	mov ds, ax
	mov es, dx		; first segment correct
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
init0_end:


	section PAYLOAD align=16 follows=INIT0
payload:
	incbin _PAYLOAD_FILE
.end:
	align 16, db 38
payload_end:


	section INIT1 align=16 follows=PAYLOAD vstart=0
init1_start:
		; INP:	ss:bp -> LOADDATA and LOADSTACKVARS
		;	ss:sp -> valid stack above [bp + ldLoadTop]
		;	cs = INIT1
		;	cs - (payload_end - payload) >> 4 => source data
		;	60h => destination
		; CHG:	ax, bx, cx, dx, es, ds, si, di

	cld
	mov ax, cs
	sub ax, ( \
		+ (payload_end - payload) \
		) >> 4
	mov ds, ax
	xor si, si		; -> source

	mov cx, (payload.end - payload) & 0FFFFh
	mov dx, (payload.end - payload) >> 16	; = length of source

	mov ax, 60h
	mov es, ax
	xor di, di		; -> destination

		; INP:	ds:si -> source
		;	dx:cx = length of source
		;	es:di -> destination (below source)
		; Note:	The destination reaches up to below the source.
	call depack
	jc error

	mov ax, 60h + _EXEC_SEGMENT
	mov bx, _EXEC_OFFSET
	push ax
	push bx
	retf


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
	push ax
	push bx
	push bp
	mov ah, 0Eh
	mov bx, 7
	int 10h
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
%if  _DEBUG1 || _DEBUG2 || _DEBUG3
.dstavaileq:	asciz "iniblz: dst_avail="
.dstsizeeq:	asciz "h dst_size="
.srcavaileq:	asciz "h src_avail="
.depackedsizeeq:asciz "h",13,10,"iniblz: depacked_size="
.len_of_dst_eq:	asciz "h length_of_destination="
.leneq:		asciz "h",13,10,"iniblz: len="
.offeq:		asciz "h off="
.tageq:		asciz "h",13,10,"iniblz: tag="
.bits_left_eq:	asciz "h bits_left="
.src_eq:	asciz "h src="
.dst_eq:	asciz "h",13,10,"iniblz: dst="
.len_of_src_eq:	asciz "h length_of_source="
.end:		asciz "h",13,10
%endif


%if 0

 BriefLZ - small fast Lempel-Ziv

 8086 Assembly lDOS iniload payload depacker

 Based on: BriefLZ C safe depacker

 Copyright (c) 2002-2016 Joergen Ibsen

 This software is provided 'as-is', without any express or implied
 warranty. In no event will the authors be held liable for any damages
 arising from the use of this software.

 Permission is granted to anyone to use this software for any purpose,
 including commercial applications, and to alter it and redistribute it
 freely, subject to the following restrictions:

   1. The origin of this software must not be misrepresented; you must
      not claim that you wrote the original software. If you use this
      software in a product, an acknowledgment in the product
      documentation would be appreciated but is not required.

   2. Altered source versions must be plainly marked as such, and must
      not be misrepresented as being the original software.

   3. This notice may not be removed or altered from any source
      distribution.

%endif

	struc BRIEFLZHEADER
blzhSignature:		resd 1	; 626C7A1Ah, big-endian ("blz\x1A")
blzhVersion:		resd 1	; 1, big-endian
blzhCompressedSize:	resd 1	; compressed data size (without header)
blzhCompressedCRC:	resd 1
blzhDecompressedSize:	resd 1	; decompressed size
blzhDecompressedCRC:	resd 1
	endstruc


depack:
	lframe near
	lvar dword,	dst_avail
	lvar dword,	dst_size
	lvar dword,	src_avail
	lvar dword,	depacked_size
	lvar dword,	length_of_destination
	lvar dword,	len
	lvar dword,	off
	lvar word,	tag
	lvar word,	bits_left
%if _DEBUG0
	lvar word,	errordata
%endif
	lenter
	lvar dword,	src
	 push ds
	 push si
	lvar dword,	dst
	 push es
	 push di
	lvar dword,	length_of_source
	 push dx
	 push cx


	 push ds
	 push si
	call pointer_to_linear

	mov bx, dx
	mov cx, ax		; bx:cx = source linear

	 push es
	 push di
	call pointer_to_linear

	sub cx, ax
	sbb bx, dx		; bx:cx = source linear - destination linear

	mov word [bp + ?length_of_destination], cx
	mov word [bp + ?length_of_destination + 2], bx


.loop:
	cmp word [bp + ?length_of_source + 2], 0
	ja @F
	cmp word [bp + ?length_of_source], BRIEFLZHEADER_size
	jae @F

%if _DEBUG0
	mov byte [bp + ?errordata + 1], 1
%endif
	cmp word [bp + ?length_of_source], 15
	ja .error
	jmp .end

@@:

	call read_be32_src		; signature

%if _DEBUG0
	mov byte [bp + ?errordata + 1], 2
%endif
	cmp ax, 7A1Ah
	jne .error
	cmp dx, 626Ch
	jne .error

	call read_be32_src		; version

%if _DEBUG0
	mov byte [bp + ?errordata + 1], 3
%endif
	cmp ax, 1
	jne .error
	test dx, dx
	jnz .error

	call read_be32_src		; compressed size

	mov word [bp + ?src_avail], ax
	mov word [bp + ?src_avail + 2], dx

%if _DEBUG0
	mov byte [bp + ?errordata + 1], 8
%endif
	add ax, BRIEFLZHEADER_size
	adc dx, 0
	jc .error

%if _DEBUG0
	mov byte [bp + ?errordata + 1], 4
%endif
	cmp dx, word [bp + ?length_of_source + 2]
	ja .error
	jb @F
	cmp ax, word [bp + ?length_of_source]
	ja .error
@@:
	sub word [bp + ?length_of_source], ax
	sbb word [bp + ?length_of_source + 2], dx

	call read_be32_src		; compressed crc

	call read_be32_src		; decompressed size

%if _DEBUG0
	mov byte [bp + ?errordata + 1], 5
%endif
	cmp dx, word [bp + ?length_of_destination + 2]
	ja .error
	jb @F
	cmp ax, word [bp + ?length_of_destination]
	ja .error
@@:
	sub word [bp + ?length_of_destination], ax
	sbb word [bp + ?length_of_destination + 2], dx

	mov word [bp + ?depacked_size], ax
	mov word [bp + ?depacked_size + 2], dx

	call read_be32_src		; decompressed crc

%if _DEBUG2
	call dump_stack_frame
%endif
	call blz_depack_safe
%if _DEBUG0
	mov byte [bp + ?errordata + 1], 6
%endif
	jc .error

%if _DEBUG0
	mov byte [bp + ?errordata + 1], 7
%endif
	cmp word [bp + ?depacked_size], ax
	jne .error
	cmp word [bp + ?depacked_size + 2], dx
	jne .error

	jmp .loop

%if _DEBUG1
.end:
	clc
	jmp .ret

.error:
	call dump_stack_frame
	stc
.ret:
%else
.end:
	db __TEST_IMM16			; (NC)
.error:
	stc
%endif

%if _DEBUG0
	mov bx, word [bp + ?errordata]
%endif

	lleave code
	lret


%if _DEBUG1 || _DEBUG2 || _DEBUG3

%define ERROR_DISPLAY empty,empty,empty,empty

	%macro add_error_display_dword 2-3.nolist _
%xdefine ERROR_DISPLAY ERROR_DISPLAY,%1,%2 + 2,%2,%3
	%endmacro

	%macro add_error_display_word 2.nolist
%xdefine ERROR_DISPLAY ERROR_DISPLAY,%1,%2,,-
	%endmacro

add_error_display_dword dstavaileq,	bp + ?dst_avail
add_error_display_dword dstsizeeq,	bp + ?dst_size
add_error_display_dword srcavaileq,	bp + ?src_avail
add_error_display_dword depackedsizeeq,	bp + ?depacked_size
add_error_display_dword len_of_dst_eq,	bp + ?length_of_destination
add_error_display_dword leneq,		bp + ?len
add_error_display_dword offeq,		bp + ?off
add_error_display_word tageq,		bp + ?tag
add_error_display_word bits_left_eq,	bp + ?bits_left
add_error_display_dword src_eq,		bp + ?src, :
add_error_display_dword dst_eq,		bp + ?dst, :
add_error_display_dword len_of_src_eq,	bp + ?length_of_source

	%macro error_display_code 4-*.nolist
%if %0 < 4
 %error Expected at least 4 arguments
%endif
%if %0 % 4
 %error Expected amount of arguments that is a multiple of 4
%endif
%rep (%0 / 4) - 1
%rotate 4
	mov si, msg.%1
	call disp_error
	mov ax, word [%2]
	call disp_ax_hex
 %ifnempty %3
  %ifidni %4, :
	mov al, ':'
	call disp_al
  %elifidni %4, _
	mov al, '_'
	call disp_al
  %endif
	mov ax, word [%3]
	call disp_ax_hex
 %endif
%endrep
	%endmacro

dump_stack_frame:
	push ax
	push ds
	push si

	push cs
	pop ds

	numdef TESTERRORDISPLAYMACRO
%if _TESTERRORDISPLAYMACRO == 0
error_display_code ERROR_DISPLAY
%else
	%macro testmacro 4-*
	numdef TESTROTATE, 4
%rotate _TESTROTATE
; %fatal 1 = %1, 2 = %2, 3 = %3, 4 = %4
	mov si, msg.%1
	call disp_error
	mov ax, word [%2]
	call disp_ax_hex
 %ifnempty %3
  %ifidni %4, :
	mov al, ':'
	call disp_al
  %elifidni %4, _
	mov al, '_'
	call disp_al
  %endif
	mov ax, word [%3]
	call disp_ax_hex
 %endif
	%endmacro

; testmacro end,bp + ?dst_avail + 2,bp + ?dst_avail,_
testmacro ERROR_DISPLAY
%endif

	mov si, msg.end
	call disp_error

	pop si
	pop ds
	pop ax
	retn
%endif


read_be32_src:
	lds si, [bp + ?src]

		; start of read_be32
		; INP:	ds:si -> data, with big-endian 32 bit word
		; OUT:	dx:ax = CPU equivalent
		;	ds:si incremented
	lodsw
	xchg ax, dx		; dx = high word (first)
	lodsw			; ax = low word (second)
	xchg al, ah
	xchg dl, dh		; fix order
		; end of read_be32

	 push ds
	 push si
	call normalise_pointer
	 pop word [bp + ?src]
	 pop word [bp + ?src + 2]
	retn


		; INP:	ss:bp -> stack frame (with blz_state equivalents)
		; OUT:	CY if error
		;	NC if success,
		;	 ax = bit
		; CHG:	ds, si, es, di
blz_getbit_safe:
	cmp word [bp + ?bits_left], 0
	jne .from_tag

%if _DEBUG0
	mov byte [bp + ?errordata], 1
%endif
	cmp word [bp + ?src_avail + 2], 0
	ja @F
	; jb .ret
	cmp word [bp + ?src_avail], 2
	jb .ret				; (CY)
@@:

	sub word [bp + ?src_avail], 2
	sbb word [bp + ?src_avail + 2], 0

	push bx
	mov bx, .lodsw
	call func_bx_with_normalised_pointers
	pop bx

	mov word [bp + ?bits_left], 16
	mov word [bp + ?tag], ax

.from_tag:
	dec word [bp + ?bits_left]
	xor ax, ax
	shl word [bp + ?tag], 1
	rcl ax, 1			; (NC)
.ret:
	retn


.lodsw:
	lodsw
	retn


		; INP:	ss:bp -> stack frame (with blz_state equivalents)
		; OUT:	CY if error
		;	NC if success,
		;	 dx:ax = gamma
		; CHG:	ds, si, es, di
blz_getgamma_safe:
	push bx

	xor dx, dx
	mov bx, 1

.loop:
	call blz_getbit_safe
%if _DEBUG0
	mov byte [bp + ?errordata], 2
%endif
	jc .ret				; (CY)
	test dh, 80h
	stc
%if _DEBUG0
	mov byte [bp + ?errordata], 3
%endif
	jnz .ret			; (CY)

	shl bx, 1
	rcl dx, 1

	or bx, ax

	call blz_getbit_safe
%if _DEBUG0
	mov byte [bp + ?errordata], 4
%endif
	jc .ret				; (CY)

	test ax, ax			; (NC)
	jnz .loop

	mov ax, bx
.ret:
	pop bx
	retn


		; INP:	ss:bp -> stack frame (with blz_state equivalents)
		;	?depacked_size set
		;	?src_avail set
		;	?src set
		;	?dst set
		; OUT:	CY if error
		;	NC if success,
		;	 dx:ax = ?dst_size
		; CHG:	ds, si, es, di, (bx), (dx), (ax), cx
blz_depack_safe:
	and word [bp + ?dst_size], 0
	and word [bp + ?dst_size + 2], 0
	and word [bp + ?bits_left], 0

	mov ax, word [bp + ?depacked_size]
	mov dx, word [bp + ?depacked_size + 2]

	mov word [bp + ?dst_avail], ax
	mov word [bp + ?dst_avail + 2], dx

	or ax, dx
	jz .ret				; (NC)

%if _DEBUG3
	call dump_stack_frame
%endif

		; Note:	Before the first iteration of .loop, move a literal.
.literal:
%if _DEBUG0
	mov byte [bp + ?errordata], 14
%endif
	xor cx, cx
	cmp word [bp + ?dst_avail + 2], cx
	jne @F
	cmp word [bp + ?dst_avail], cx
	je .ret_CY
@@:

%if _DEBUG0
	mov byte [bp + ?errordata], 15
%endif
	cmp word [bp + ?src_avail + 2], cx
	jne @F
	cmp word [bp + ?src_avail], cx
	je .ret_CY
@@:

	sub word [bp + ?dst_avail], 1
	sbb word [bp + ?dst_avail + 2], cx

	sub word [bp + ?src_avail], 1
	sbb word [bp + ?src_avail + 2], cx

	mov bx, .movsb
	call func_bx_with_normalised_pointers

	add word [bp + ?dst_size], 1
	adc word [bp + ?dst_size + 2], 0

.loop:
	mov ax, word [bp + ?dst_size]
	mov dx, word [bp + ?dst_size + 2]

	cmp dx, word [bp + ?depacked_size + 2]
	ja .end
	jb @F
	cmp ax, word [bp + ?depacked_size]
	jae .end
@@:

	call blz_getbit_safe
%if _DEBUG0
	mov byte [bp + ?errordata], 7
%endif
	jc .ret_CY

	test ax, ax
	jz .literal

	call blz_getgamma_safe
%if _DEBUG0
	mov byte [bp + ?errordata], 8
%endif
	jc .ret_CY
	mov cx, ax
	mov bx, dx			; bx:cx = len

	call blz_getgamma_safe
%if _DEBUG0
	mov byte [bp + ?errordata], 9
%endif
	jc .ret_CY			; dx:ax = off

	add cx, 2
	adc bx, 0			; len += 2

	sub ax, 2
	sbb dx, 0			; off -= 2

%if _DEBUG0
	mov byte [bp + ?errordata], 10
%endif
	cmp dx, 00FFh
	ja .ret_CY
	jb @F
	cmp ax, 0FFFFh			; off >= 00FF_FFFFh ?
	jae .ret_CY			; return error if so
@@:

%if _DEBUG0
	mov byte [bp + ?errordata], 11
%endif
	cmp word [bp + ?src_avail + 2], 0
	jne @F
	cmp word [bp + ?src_avail], 0	; src_avail != 0 ?
	je .ret_CY			; return error if == 0
@@:

	sub word [bp + ?src_avail], 1
	sbb word [bp + ?src_avail + 2], 0	; src_avail--

	mov word [bp + ?len], cx
	mov word [bp + ?len + 2], bx

	mov cx, 8
@@:
	shl ax, 1
	rcl dx, 1			; off <<= 8
	loop @B

	mov word [bp + ?off], ax
	mov word [bp + ?off + 2], dx

	xor ax, ax
	mov bx, .lodsb
	call func_bx_with_normalised_pointers

	inc ax				; *src + 1
	add word [bp + ?off], ax
	adc word [bp + ?off + 2], 0	; + off

	mov ax, word [bp + ?depacked_size]
	mov dx, word [bp + ?depacked_size + 2]

	sub ax, word [bp + ?dst_avail]
	sbb dx, word [bp + ?dst_avail + 2]

%if _DEBUG0
	mov byte [bp + ?errordata], 12
%endif
	cmp word [bp + ?off + 2], dx
	ja .ret_CY
	jb @F
	cmp word [bp + ?off], ax	; off > depacked_size - dst_avail ?
	ja .ret_CY			; return error if so
@@:

	mov ax, word [bp + ?len]
	mov dx, word [bp + ?len + 2]

%if _DEBUG0
	mov byte [bp + ?errordata], 13
%endif
	cmp dx, word [bp + ?dst_avail + 2]
	ja .ret_CY
	jb @F
	cmp ax, word [bp + ?dst_avail]	; len > dst_avail ?
	ja .ret_CY			; return error if so
@@:

	sub word [bp + ?dst_avail], ax
	sbb word [bp + ?dst_avail + 2], dx	; dst_avail -= len


	add word [bp + ?dst_size], ax
	adc word [bp + ?dst_size + 2], dx	; dst_size += len


	lds si, [bp + ?dst]		; pp = dst

	mov bx, word [bp + ?off + 2]
	mov cx, word [bp + ?off]

        neg bx
        neg cx
        sbb bx, byte 0          	; neg bx:cx

	 push ds
	 push si
	call normalise_pointer_with_displacement_bxcx
	 pop si
	 pop ds				; ds:si = pp = dst - off

	les di, [bp + ?dst]		; es:di = dst

.loop_copy_match:
	mov cx, 64 * 1024 - 16		; block size

	test dx, dx			; >= 1_0000h ?
	jnz @F				; yes, full block -->

	test ax, ax			; == 0 ?
	jz .end_copy_match		; yes, done -->

	cmp ax, cx			; can move in one (last) block ?
	jbe .last_copy_match		; yes -->
@@:
					; no, move one block and continue
	sub ax, cx
	sbb dx, 0			; left over remaining

	jmp .copy_match

.last_copy_match:
	xchg cx, ax			; cx = remaining len
	xor ax, ax			; no more remaining

.copy_match:

	rep movsb			; move one block (full or partial)

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

	jmp .loop_copy_match


.end_copy_match:
	mov word [bp + ?dst], di
	mov word [bp + ?dst + 2], es

	jmp .loop


.end:
	mov ax, word [bp + ?dst_size]
	mov dx, word [bp + ?dst_size + 2]
	clc
	retn

.ret_CY:
	stc
.ret:
	retn


.lodsb:
	lodsb
	retn

.movsb:
	movsb
	retn


		; INP:	?dst -> destination
		;	?src -> source
		;	bx = function to call with pointers
		; CHG:	ds, si, es, di
		; OUT:	function called,
		;	?dst and ?src advanced (if function changed the regs)
func_bx_with_normalised_pointers:
	les di, [bp + ?dst]
	lds si, [bp + ?src]

	call bx

	 push ds
	 push si
	call normalise_pointer
	 pop word [bp + ?src]
	 pop word [bp + ?src + 2]

	 push es
	 push di
	call normalise_pointer
	 pop word [bp + ?dst]
	 pop word [bp + ?dst + 2]

	retn


	lleave ctx


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

	push ax
	and ax, 15
	mov word [bp + ?offset], ax
	pop ax

%rep 4
	shr dx, 1
	rcr ax, 1
%endrep
	mov word [bp + ?segment], ax

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

